#!/bin/julia

# plan: collate snorkel-relevant stuff and make an image for e-ink displays to grab
# - extra credit: location configurable, format configurable, colour / dithering, bits per pixel etc

using GLMakie, DataFrames, CSV, Dates

# meteociel. no api so will need to scrape :(
# Cascadia CSS selector

import Cascadia, HTTP, Gumbo

vagues = HTTP.get("https://www.meteociel.fr/previsions-mer-vagues-houle/2074/villefranche_sur_mer.htm")
vagues_body = String(vagues.body)

vagues_parsed = Gumbo.parsehtml(vagues_body)

tables = collect(eachmatch(Cascadia.Selector("table table table"), vagues_parsed.root))
# t = collect(eachmatch(Cascadia.Selector("tbody > tr > td"), tables[2])) # get headers

# just brute it
# ... arrvggggghghghghghghhghgharrggghghghghgg considering just using pandas
rows = []
for (i, raw_row) in enumerate(eachmatch(Cascadia.Selector("tbody > tr"), tables[2]))
    row = []
    for (j, cell) in enumerate(eachmatch(Cascadia.Selector("td"), raw_row))
        rspan = parse(Int, get(cell.attributes, "rowspan", "1"))
        cspan = parse(Int, get(cell.attributes, "colspan", "1"))
        # how the fuck do i deal with rowspan
        rspan != 1 && continue
        for _ in 1:cspan
            push!(row, Gumbo.text(cell))
        end
    end
    push!(rows, row)
end
rows


# going to just use python call coz read_html is bloody 1,300 lines long

using PythonCall
import CondaPkg
CondaPkg.add(["pandas", "lxml"])
pd = pyimport("pandas")

table_str = string(tables[2])
pls = string(pd.read_html(table_str)[0].to_csv()) # no idea why this has to be the first element

df_raw = CSV.read(IOBuffer(pls), DataFrame) # omg finally
df_raw[!, 2:end]
col_names = zip(Array(df_raw[1, 2:end]), Array(df_raw[2, 2:end])) .|> unique .|> s -> join(s, " ")
df = df_raw[3:end, 2:end]
rename!(df, Dict(enumerate(col_names)))
df[!, 8:end] # 8 = vagues haut, 3 # temp
df[!, 3:end] # 8 = vagues haut, 3 temp, 7 gusts

# parsing dates is kinda annoying but we can probably cheat

times_working = Dates.today() .+ Time.(df[!, 2])
for (i,_) in enumerate(times_working[2:end])
    if times_working[i+1] < times_working[i] # i is always i-1
        times_working[(i+1):end] .+= Day(1)
    end
end
times_working

df[!, 2] = times_working
df[!, 3] = parse.(Float64, df[!, 3])
df[!, 8] = parse.(Float64, df[!, 8])
df[!, 7] = parse.(Float64, df[!, 7])

using Makie.Dates, Makie.Unitful # shrug. not clear if we needed these
lines(df[!, 2], df[!, 3]) # air temperature (i think)
barplot(df[!, 2], df[!, 8]) # cool we are getting somewhere
lines(df[!, 2], df[!, 7]) # wind

# it'd be nice to have cloud cover too but they use an image for that which pandas doesn't support. 

# it would be too easy if we could just replace these
# for m in eachmatch(Cascadia.Selector("img"), vagues_parsed.root)
#     m = Gumbo.HTMLText(get(m.attributes, "alt", ""))
# end
# 
# using AbstractTrees
# for e in PreOrderDFS(vagues_parsed.root)
#     try
#         if(Gumbo.tag(e) == :img)
#             e = Gumbo.HTMLText(get(e.attributes, "alt", ""))
#             push!(e.parent, Gumbo.HTMLText(get(e.attributes, "alt", "")))
#         end
#     catch(o)
#         @warn o
#     end
# end
# 
# none of this works i give up for now



# jellyfish. this will surely be easier
using JSON
jelly_raw = HTTP.get("https://meduse.acri.fr/api/v1/campaigns/meduse/observations?lang=en&campaign=meduse&filter=location+geointersects+%27POLYGON((43.71832631212757+7.340712547302247,43.71832631212757+7.292132377624513,43.68196347975282+7.292132377624513,43.68196347975282+7.340712547302247,43.71832631212757+7.340712547302247))%27+and+observation_date+ge+%272025-01-01T16:44:11.497Z%27&count=true&limit=50&skip=0&orderby=observation_date+desc").body |> String
# should automatically update date here

jelly = JSON.parse(jelly_raw)["value"]
map(j -> j["data"]["quantity"], jelly)

# many, several, one, none. e.g. map to 8, 5, 1, 0
word2num = Dict(
    "many" => 8,
    "several" => 5,
    "one" => 1,
    "none" => 0
)

# all the times are zulu time. just like Dates ones.
jelly_df = DataFrame(date=map(j -> DateTime(j["observation_date"][1:end-1]), jelly), n_jellies=map(j -> word2num[get(j["data"], "quantity", "none")], jelly))
window_size = 24
probes = collect((Dates.now() - Dates.Month(1)):Hour(window_size):(Dates.now()+Hour(window_size)))
jelly_probed_df = DataFrame(date_start=probes[1:end-1], date_end=probes[2:end], n_jellies=fill(0, length(probes)-1))

for (i, r) in enumerate(eachrow(jelly_probed_df))
    jelly_probed_df.n_jellies[i] = sum(jelly_df[r.date_start .<= jelly_df.date .< r.date_end, :n_jellies])
end
lines(jelly_probed_df.date_end, jelly_probed_df.n_jellies) # nice. but what do we do if there's just zero data?


f = Figure()
Axis(f[1,1], title="jellies")
lines!(f[1,1], jelly_probed_df.date_end, jelly_probed_df.n_jellies) # nice. but what do we do if there's just zero data?
Axis(f[1,2], title="air temp")
lines!(f[1,2], df[!, 2], df[!, 3]) # air temperature (i think)
Axis(f[2,1], title="wave height")
barplot!(f[2,1], df[!, 2], df[!, 8]) # cool we are getting somewhere
Axis(f[2,2], title="wind")
lines!(f[2,2], df[!, 2], df[!, 7]) # wind


# hehe this is getting good. would be nice to have cloud cover. could use a different api i guess. and then we want train times too
# train times -> prettytables -> monospace font -> text
