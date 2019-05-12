function shots_lf(live_feed_output)
    shots = [evnts for evnts in pairs(live_feed_output[:liveData][:plays][:allPlays]) if evnts[2][:result][:event] == "Shot"]

    shtr = DataFrame([dropnames(evnt[2][:players][1][:player], (:link, )) for evnt in shots])
    rename!(shtr, :id => :idShooter)
    rename!(shtr, :fullName => :fullNameShooter)

    tm = DataFrame([dropnames(evnt[2][:team], (:link, :triCode, )) for evnt in shots])
    rename!(tm, :id => :idTeam)
    rename!(tm, :name => :nameTeam)

    goalie = DataFrame([dropnames(evnt[2][:players][2][:player], (:link, )) for evnt in shots])
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

    return fullframe
end
