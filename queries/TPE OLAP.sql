-- 1.a ¿Cuál es el Lateral Izquierdo de jerarquía con más de 10 asistencias y con menos tarjetas recibidas
--     en las últimas dos temporadas que podemos traer al club por menos de £18.000.000?

with player_with_age as (
            select p.playerid as player_id,
                   p.name,
                   extract(year from age(CURRENT_DATE,p.dateofbirth)) as age,
                   p.countryid,
                   p.playerid,
                   positionid,
                   height,
                   foot,
                   marketvalue
            from player p
            where p.dateofbirth IS NOT NULL),

    last_two_season_games as (
            select *
            from game g
                join time t on g.gamedateid = t.timekey
            where t.season = '2021-2022' or  t.season = '2020-2021'
    )


select p.name,
       sum(assists) as total_assists,
       (sum(yellowcards)+sum(redcards)) as total_cards,
       age,
       marketvalue
from playergameperformance pgf
        join last_two_season_games g on pgf.gameid = g.gameid
        join player_with_age p on p.playerid = pgf.playerid
        join subposition s on p.positionid = s.subpositionid
where s.subpositionname = 'Defender - Left-Back'
        and p.marketvalue < 18000000
        and p.age >= 28
group by p.playerid,p.name, age, marketvalue
order by total_assists desc , total_cards;


---2.a ¿Cual es el defensor joven con más minutos jugados en las últimas
-- tres ediciones de champions league con un precio menor a £7.000.000?

with young_players_defenders_mktvalue as (
    select *
    from player p natural join position as pos
    where  extract(year from age(CURRENT_DATE,p.dateofbirth)) <=23 and p.marketvalue <= 7000000 and pos.positionname = 'Defender'
),
young_players as (
    select *
    from player p
    where  extract(year from age(CURRENT_DATE,p.dateofbirth)) <=23
),
champions_played_times as (
    SELECT perf.playerid, SUM(perf.minutesplayed) AS sum FROM playergameperformance AS perf NATURAL JOIN game AS g
    WHERE g.competitionid = 'CL' AND g.gamedateid IN (
        SELECT aux.timekey FROM time as aux
        WHERE season = '2019-2020' or season = '2020-2021' or season = '2021-2022'
    )
    GROUP BY perf.playerid
)
SELECT DISTINCT young_players.name, young_players.playerid, champions_played_times.sum as minutes_played, young_players.marketvalue as market_value FROM young_players_defenders_mktvalue as young_players NATURAL JOIN champions_played_times
ORDER BY champions_played_times.sum DESC
LIMIT 1;

---2.b ¿Cuales son los 5 delanteros jóvenes más baratos con más de 20 goles en las últimas dos temporadas?
with young_players as (
    select *
    from player p
    where  extract(year from age(CURRENT_DATE,p.dateofbirth)) <=23
),
played_last_two_seasons as (
    SELECT DISTINCT g2.gameid FROM game AS g2
    WHERE gamedateid IN (
            SELECT aux.timekey FROM time as aux
            WHERE season = '2020-2021' or season = '2021-2022'
        )
)
SELECT DISTINCT young_players.name, young_players.marketvalue, SUM(playergameperformance.goals) FROM young_players NATURAL JOIN playergameperformance
WHERE gameid IN (SELECT * FROM played_last_two_seasons)
GROUP BY young_players.playerid, young_players.name,young_players.marketvalue
HAVING SUM(playergameperformance.goals) >= 20
ORDER BY young_players.marketvalue;

-- 3.b Identificar a los 4 mejores mediocampista centrales de la Premier League de acuerdo a asistencias,
--     minutos jugados y goles en contra que recibió su equipo con un valor menor a £20.000.000.

with last_premierlegue_games as (
    select gameid
    from game g
        join competition c on g.competitionid = c.competitionid
        join time t on g.gamedateid = t.timekey
    where c.competitionid = 'GB1' and t.season = '2021-2022'
)

select p.name , sum(assists) as assists , sum(minutesplayed) as minutes_played, p.marketvalue
from player p
    join playergameperformance p2 on p.playerid = p2.playerid
    join subposition s on p.positionid = s.subpositionid
    join last_premierlegue_games pg on  pg.gameid = p2.gameid
where p.marketvalue < 20000000
    and s.subpositionname = 'midfield - Central Midfield'
group by p.playerid, p.name
order by assists desc , minutes_played desc
limit 4;

-- 4.a Identificar 20 delanteros centrales con un promedio de gol mayor 0.3 goles/partido y con
--     una altura mayor a 1.8mts de la última temporada.

with strikeers as  (

    select p.playerid,p.name, CAST(sum(goals) AS double precision)/count(distinct g.gameid) goals_per_game
        from player p
            join playergameperformance pgp on pgp.playerid = p.playerid
            join club c on pgp.clubid = c.clubid
            join game g on g.gameid = pgp.gameid
            join time t on t.timekey = g.gamedateid
            join subposition s on p.positionid = s.subpositionid
        where t.season = '2021-2022'
            and s.subpositionname = 'attack - Centre-Forward'
            and height >= 1.8
        group by p.playerid,p.name
        order by goals_per_game desc
)

select name, goals_per_game
    from strikeers
where goals_per_game > 0.3
order by goals_per_game desc
limit 20;

-- 4.b Identificar 10 extremos izquierdo zurdos con un promedio de asistencia mayor a 0.2 asistencia/partido.

with assist_players as (

    select p.playerid,p.name, CAST(sum(assists) AS double precision)/count(distinct g.gameid) assist_per_game
        from player p
            join playergameperformance pgp on pgp.playerid = p.playerid
            join club c on pgp.clubid = c.clubid
            join game g on g.gameid = pgp.gameid
            join time t on t.timekey = g.gamedateid
            join subposition s on p.positionid = s.subpositionid
        where t.season = '2021-2022'
            and s.subpositionname = 'attack - Left Winger'
            and foot = 'Left'
        group by p.playerid,p.name
        order by assist_per_game desc
)

select name, assist_per_game
    from assist_players
where assist_per_game> 0.3
order by assist_per_game desc
limit 10;


-- 5.a Identificar los clubes con una cantidad de jóvenes en la plantilla mayor al promedio de cada país.

with young_players_per_club as (
    select c.clubid club_id, c.name club_name, c.countryid country_team_id, count(distinct p.playerid) club_count
    from player p
        join playergameperformance pgp on pgp.playerid = p.playerid
        join club c on pgp.clubid = c.clubid
        join game g on g.gameid = pgp.gameid
        join time t on t.timekey = g.gamedateid
    where t.season = '2021-2022'
        and extract(year from age(CURRENT_DATE,p.dateofbirth)) <=23
    group by c.clubid, c.name, c.countryid
    order by club_count desc
),

young_players_per_country_team as(
    select countryname, countryid, round(sum(club_count)/count(club_id),2) as country_avg
    from young_players_per_club yp
            join country c on c.countryid = yp.country_team_id
    group by countryname, countryid
    order by country_avg desc
)


select club_name, club_count, country_avg
    from  young_players_per_country_team yppct
    join young_players_per_club yp on yppct.countryid = yp.country_team_id
where club_count > country_avg
order by club_count desc
limit 5;


---6.b ¿Cuál es la competencia con menor cantidad de tarjetas rojas por partido de las últimas 3 temporadas?

SELECT c.name, CAST(SUM(p.redcards) AS FLOAT)/COUNT(g.gamedateid) as avg FROM competition as c NATURAL JOIN game as g NATURAL JOIN playergameperformance as p
WHERE g.gamedateid IN (
        SELECT aux.timekey FROM time as aux
        WHERE season = '2019-2020' or season = '2020-2021' or season = '2021-2022'
    )
GROUP BY c.competitionid
HAVING COUNT(g.gamedateid) > 3000
ORDER BY avg
LIMIT 1;




