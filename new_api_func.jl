using HTTP, JSON2, DataFrames

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

function dropnames(namedtuple::NamedTuple, names::Tuple{Vararg{Symbol}}) # This deletes a tuple from a NamedTuple by name
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

temp = get_box_score(2018030321)
homestats = DataFrame(stats_dressed_skaters(temp, :home))
awaystats = DataFrame(stats_dressed_skaters(temp, :away))
