#!/bin/julia

# plan: collate snorkel-relevant stuff and make an image for e-ink displays to grab
# - extra credit: location configurable, format configurable, colour / dithering, bits per pixel etc

using CairoMakie, DataFrames, CSV, Dates, PythonCall, JSON, Memoization

# meteociel. no api so will need to scrape :(
# Cascadia CSS selector

import Cascadia, HTTP, Gumbo, CondaPkg, MakieThemes
CondaPkg.add(["pandas", "lxml"])
pd = pyimport("pandas")
# lines(jelly_probed_df.date_end, jelly_probed_df.n_jellies) # nice. but what do we do if there's just zero data?

jelly_window = Dates.Week(1)
# e.g. grab_data(floor(Dates.now(), Dates.Hour))
@memoize function grab_data(timestamp) # timestamp only used for cache
    vagues = HTTP.get("https://www.meteociel.fr/previsions-mer-vagues-houle/2074/villefranche_sur_mer.htm")
    vagues_body = String(vagues.body)
    vagues_parsed = Gumbo.parsehtml(vagues_body)
    tables = collect(eachmatch(Cascadia.Selector("table table table"), vagues_parsed.root))

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

    # lines(df[!, 2], df[!, 3]) # air temperature (i think)
    # barplot(df[!, 2], df[!, 8]) # cool we are getting somewhere
    # lines(df[!, 2], df[!, 7]) # wind

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
    
    # # includes eastern bay of st jean cap ferrat
    # jelly_raw = HTTP.get("https://meduse.acri.fr/api/v1/campaigns/meduse/observations?lang=en&campaign=meduse&filter=location+geointersects+%27POLYGON((43.71832631212757+7.340712547302247,43.71832631212757+7.292132377624513,43.68196347975282+7.292132377624513,43.68196347975282+7.340712547302247,43.71832631212757+7.340712547302247))%27+and+observation_date+ge+%272025-01-01T16:44:11.497Z%27&count=true&limit=50&skip=0&orderby=observation_date+desc").body |> String
    # # literally just villefranche_sur_mer
    # nice
    # https://meduse.acri.fr/api/v1/campaigns/meduse/observations?lang=en&campaign=meduse&filter=location+geointersects+%27POLYGON((43.70756248159074+7.290029525756837,43.70756248159074+7.23552703857422,43.67516627295159+7.23552703857422,43.67516627295159+7.290029525756837,43.70756248159074+7.290029525756837))%27+and+observation_date+ge+%272025-04-25T18:39:42.669Z%27&count=true&limit=50&skip=0&orderby=observation_date+desc
    villefrance_url = "https://meduse.acri.fr/api/v1/campaigns/meduse/observations?lang=en&campaign=meduse&filter=location+geointersects+%27POLYGON((43.71144016493395+7.327322959899903,43.71144016493395+7.300372123718263,43.679046051522036+7.300372123718263,43.679046051522036+7.327322959899903,43.71144016493395+7.327322959899903))%27+and+observation_date+ge+%27$(Dates.now() - jelly_window)Z%27&count=true&limit=50&skip=0&orderby=observation_date+desc"
    nice_url = "https://meduse.acri.fr/api/v1/campaigns/meduse/observations?lang=en&campaign=meduse&filter=location+geointersects+%27POLYGON((43.70756248159074+7.290029525756837,43.70756248159074+7.23552703857422,43.67516627295159+7.23552703857422,43.67516627295159+7.290029525756837,43.70756248159074+7.290029525756837))%27+and+observation_date+ge+%27$(Dates.now() - jelly_window)Z%27&count=true&limit=50&skip=0&orderby=observation_date+desc"
    jelly_probed_vf = grabjellies(villefrance_url)
    jelly_probed_nice = grabjellies(nice_url)

    return (df, jelly_probed_vf, jelly_probed_nice)
end

function grabjellies(url)
    jelly_raw = HTTP.get(url).body |> String
    # should automatically update date here

    jelly = JSON.parse(jelly_raw)["value"]
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
    probes = collect((Dates.now() - jelly_window):Hour(window_size):(Dates.now()+Hour(window_size)))
    jelly_probed_df = DataFrame(date_start=probes[1:end-1], date_end=probes[2:end], n_jellies=fill(0, length(probes)-1))

    for (i, r) in enumerate(eachrow(jelly_probed_df))
        jelly_probed_df.n_jellies[i] = sum(jelly_df[r.date_start .<= jelly_df.date .< r.date_end, :n_jellies])
    end
    return jelly_probed_df
end


#f = Figure(; merge(MakieThemes.style_bbc(), MakieThemes.ggthemr(:greyscale))..., # lol no x axis at all

function makegraphspls(height=1024, width=758)
    df, jelly_probed_vf, jelly_probed_nice = grab_data(floor(Dates.now(), Dates.Minute(30))) # don't hammer their apis
    # this should really, really be cached. could maybe use https://github.com/marius311/Memoization.jl with a loop clearing the cache at set times
    f = Figure(; size=(width/2, height/2), #MakieThemes.ggthemr(:greyscale)..., # defaults to 2x size ...
        fonts = (;
            #regular = "Dina TTF", # doesn't work :(
            bold = "Iosevka Term",
        ), fontsize = 12,
    )
    ax = Axis(f[1,1], ylabel="jellies", xticklabelrotation=pi/8)
    # makie doesn't seem to fully support dates :(
    limits!(ax, (Dates.now()-jelly_window).instant.periods.value, Dates.now().instant.periods.value, nothing, nothing)
    lines!(f[1,1], jelly_probed_vf.date_end, jelly_probed_vf.n_jellies, color=:black, label="vf") # nice. but what do we do if there's just zero data?
    lines!(f[1,1], jelly_probed_nice.date_end, jelly_probed_nice.n_jellies, color=:black, linestyle=:dash, label="nice") # nice.
    axislegend(ax, merge=true, unique=true, framevisible=false, position=:lt)
    Axis(f[1,2], ylabel="water temp", xticklabelrotation=pi/8)
    lines!(f[1,2], df[!, 2], df[!, 3], color=:black) # water temp. probably
    Axis(f[2,1], ylabel="wave height", xticklabelrotation=pi/8)
    barplot!(f[2,1], df[!, 2], df[!, 8], color=:black) # cool we are getting somewhere
    Axis(f[2,2], ylabel="wind", xticklabelrotation=pi/8)
    lines!(f[2,2], df[!, 2], df[!, 7], color=:black) # wind
    Label(f[:, 3], string(Dates.now()), valign=:top, fontsize=10, rotation=pi/2)
    return f
end

# hehe this is getting good. would be nice to have cloud cover. could use a different api i guess. and then we want train times too
# train times -> prettytables -> monospace font -> text

# resolution: 758x1024

# server
API_VERSION = "0.0.1"
PORT = get(ENV, "JULIA_API_PORT", 53113)
IN_PRODUCTION = !isinteractive()

using Oxygen

import ImageTransformations: imrotate
import HTTP
using FileIO

# adapted from Oxygen.jl/ext/CairoMakieExt.jl
function mypng(fig, rot)
    io = IOBuffer()
    show(io, MIME("image/png"), fig)
    img = load(io)
    img = imrotate(img, rot)
    io2 = IOBuffer()
    save(FileIO.Stream(format"PNG", io2), img)
    body = take!(io2)
    resp = HTTP.Response(200, [], body)
    HTTP.setheader(resp, "Content-Type" => "image/png")
    HTTP.setheader(resp, "Content-Length" => string(sizeof(body)))
    return resp
end

@get "/graph" function()
    mypng(makegraphspls(758, 1024), pi/2) # todo: 4 bits per pixel rather than 8
end

serve(; host="0.0.0.0", port=PORT)
