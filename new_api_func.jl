using HTTP, JSON2, DataFrames, CSV

function get_box_score(gameid)
    url = string("https://statsapi.web.nhl.com/api/v1/game/", gameid, "/boxscore")
    r = HTTP.request("GET", url)
    res = JSON2.read(String(r.body))
    return res
end

function get_live_feed(gameid)
    url = string("https://statsapi.web.nhl.com/api/v1/game/", gameid, "/feed/live")
    r = HTTP.request("GET", url)
    res = JSON2.read(String(r.body))
    return res
end

function team_names(box_score_output)
    r = NamedTuple{(:away, :home)}((box_score_output[:teams][:away][:team][:name], box_score_output[:teams][:home][:team][:name]))
    return r
end

function coach_names(box_score_output)
    r = NamedTuple{(:away, :home)}((box_score_output[:teams][:away][:coaches][1][:person][:fullName], box_score_output[:teams][:home][:coaches][1][:person][:fullName]))
    return r
end

function score_summary(box_score_output)
    awy = box_score_output[:teams][:away][:teamStats][:teamSkaterStats]
    hom = box_score_output[:teams][:home][:teamStats][:teamSkaterStats]
    r = NamedTuple{(:away, :home)}((awy, hom))
    return r
end

function dressed_skaters(box_score_output, side)
    tm = box_score_output[:teams][side][:players]
    inter = [plr for plr in pairs(tm) if !(plr[2][:position][:code] in ["G", "N/A"])]
    f = (; inter...)
    return f
end

# This deletes a tuple from a NamedTuple by name
function dropnames(namedtuple::NamedTuple, names::Tuple{Vararg{Symbol}})
    keepnames = Base.diff_names(Base._nt_names(namedtuple), names)
    return NamedTuple{keepnames}(namedtuple)
end

function player_summary(player_element)
    nm = NamedTuple{(:id, :firstName, :lastName)}((player_element[:person][:id], player_element[:person][:firstName], player_element[:person][:lastName]))
    st = player_element[:stats][:skaterStats]
    st = dropnames(st, (:faceOffPct, ))
    comb = merge(nm, st)
    return comb
end

function stats_dressed_skaters(box_score_output, side)
    tm = dressed_skaters(box_score_output, side)
    player_ids = keys(tm)
    player_sts = [player_summary(plr) for plr in tm]
    r = NamedTuple{Tuple(player_ids)}(player_sts)
    return r
end

function extract_goalie(sht_elem)
    ret = Array{NamedTuple{(:player, :playerType), Tuple{NamedTuple{(:id, :fullName, :link), Tuple{Int64, String, String}}, String}}, 1}(undef, 1)
    r = [elm for elm in sht_elem if elm[:playerType] == "Goalie"]
    if length(r) > 0
        ret[1] = r[1]
    else
        ret[1] = (player = (id = -99, fullName = "Empty net", link = "l"), playerType = "Goalie")
    end
    return ret
end

function shots_lf(live_feed_output)
    shots = [evnts for evnts in pairs(live_feed_output[:liveData][:plays][:allPlays]) if evnts[2][:result][:event] in ["Shot", "Goal"]]

    shtr = DataFrame([dropnames(evnt[2][:players][1][:player], (:link, )) for evnt in shots])
    rename!(shtr, :id => :idShooter)
    rename!(shtr, :fullName => :fullNameShooter)

    tm = DataFrame([dropnames(evnt[2][:team], (:link, :triCode, )) for evnt in shots])
    rename!(tm, :id => :idTeam)
    rename!(tm, :name => :nameTeam)

    tm[:shotNumber] = 1:nrow(tm)

    gls = [sts[2][:players] for sts in shots]
    goalie = DataFrame([dropnames(extract_goalie(evnt)[1][1], (:link, )) for evnt in gls])
    rename!(goalie, :id => :idGoalie)
    rename!(goalie, :fullName => :fullNameGoalie)

    fullframe = hcat(shtr, tm)
    fullframe = hcat(fullframe, goalie)

    fullframe[:shotType] = [evnt[2][:result][:secondaryType] for evnt in shots]

    whn = DataFrame([dropnames(evnt[2][:about], (:eventIdx, :eventId, :ordinalNum, :periodTimeRemaining, :goals, )) for evnt in shots])
    fullframe = hcat(fullframe, whn)

    fullframe[:goalsAway] = [evnt[2][:about][:goals][:away] for evnt in shots]
    fullframe[:goalsHome] = [evnt[2][:about][:goals][:home] for evnt in shots]
    fullframe[:coordX] = [evnt[2][:coordinates][:x] for evnt in shots]
    fullframe[:coordY] = [evnt[2][:coordinates][:y] for evnt in shots]

    isgoal = falses(nrow(fullframe))
    for i = 1:length(isgoal)
        if i == 1
            if (fullframe[1, :goalsAway] == 1) | (fullframe[1, :goalsHome] == 1)
                isgoal[1] = true
            end
        else
            if (fullframe[i, :goalsAway] != fullframe[i - 1, :goalsAway]) | (fullframe[i, :goalsHome] != fullframe[i - 1, :goalsHome])
                isgoal[i] = true
            end
        end
    end
    fullframe[:isGoal] = isgoal

    return fullframe
end

function write_shots_lf(gameid, path)
    if !isdir(path)
        error("The specified folder doesn't exist. Check the name and try again.")
    else
        tbl = get_live_feed(gameid)
        shots = shots_lf(tbl)
        shots[:gameId] = gameid
        shots = shots[:, vcat(ncol(shots), collect(1:(ncol(shots)- 1)))]
        CSV.write(string(path, "/", gameid, ".csv"), shots)
    end
end

function season_write_shots_lf(season, path)
    if season >= 2017
        numgames = 1281
    else
        numgames = 1280
    end
    gameids = [string(season, "02", string(id, pad = 4)) for id in 1:numgames] # "02" here stands for regular season
    for i = 1:numgames
        println(string("Getting and writing gameid ", gameids[i], "."))
        write_shots_lf(gameids[i], path)
    end
end
