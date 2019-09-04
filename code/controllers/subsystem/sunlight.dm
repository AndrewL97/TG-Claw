/*  6:00 AM 	- 	21600
	6:45 AM 	- 	24300
	11:45 AM 	- 	42300
	4:45 PM 	- 	60300
	9:45 PM 	- 	78300
	10:30 PM 	- 	81000 */
#define CYCLE_SUNRISE 	216000
#define CYCLE_MORNING 	243000
#define CYCLE_DAYTIME 	423000
#define CYCLE_AFTERNOON 603000
#define CYCLE_SUNSET 	783000
#define CYCLE_NIGHTTIME 810000



GLOBAL_VAR_INIT(GLOBAL_LIGHT_RANGE, 3)
GLOBAL_LIST_EMPTY(SUNLIGHT_QUEUE_WORK)   /* turfs to be stateChecked */
GLOBAL_LIST_EMPTY(SUNLIGHT_QUEUE_UPDATE) /* turfs to have their colours updated via corners (filter out the unroofed dudes) */
GLOBAL_LIST_EMPTY(SUNLIGHT_QUEUE_CORNER) /* turfs to have their colour/lights/etc updated */
GLOBAL_LIST_EMPTY(SUNLIGHT_OVERLAYS)
// /var/total_sunlight_overlays = 0
// /var/sunlight_overlays_initialised = FALSE

// GLOBAL_LIST_INIT(globSunBackdrop, list (new/obj/lighting_general))
// cannibalized from lighting.dm



/*
    on initialize - all sunlight_overlays will set theirs states
    1 - full square
    2 - off (roofed)
    3 - lighting
    4 - lighting neighbour - we need to do cornering stuff to cancel out the lighting from #3

    on stateCheck:
		states that were 3, or are now 3 will add their neighbours to the state 4 queue to be processed

    Timechange:
		runs when we are changing to a new time bracket, and need to set a new colour, light intensity, etc.
		After setting new lighting vars
		    run updateColour with GLOBAL_LIGHT_OVERLAYS as target, to update everything

    updateColour:
		loop over target list to run the sunlight_overlay.updateColour proc


*/

SUBSYSTEM_DEF(sunlight)
	name = "sunlight"
	wait = 1
	flags = SS_TICKER
	init_order = INIT_ORDER_SUNLIGHT

	var/screenColour = COLOR_ASSEMBLY_BEIGE //rando spin
	var/list/obj/screen/plane_master/lighting/sunlighting_planes = list()

	var/color = "#FFFFFF"
	var/list/cornerColour = list()

	var/currentTime

datum/controller/subsystem/sunlight/stat_entry()
	..("L:[GLOB.SUNLIGHT_QUEUE_WORK.len]|C:[GLOB.SUNLIGHT_QUEUE_CORNER.len]|O:[GLOB.SUNLIGHT_QUEUE_UPDATE.len]")

datum/controller/subsystem/sunlight/proc/fullPlonk()
	var/msg = "b4 wq [GLOB.SUNLIGHT_QUEUE_WORK.len]"
	to_chat(world, "<span class='boldannounce'>[msg]</span>")
	log_world(msg)
	GLOB.SUNLIGHT_QUEUE_WORK = GLOB.SUNLIGHT_OVERLAYS
	msg = "af wq [GLOB.SUNLIGHT_QUEUE_WORK.len]"
	to_chat(world, "<span class='boldannounce'>[msg]</span>")
	log_world(msg)

/datum/controller/subsystem/sunlight/Initialize()
	if(!initialized)
		InitializeTurfs()
		fullPlonk()
		initialized = TRUE
	fire(FALSE, TRUE)

	// l_sunPlane = new()
	// l_sun = new()
	// sunlight_overlays_initialised = TRUE
	..()

// It's safe to pass a list of non-turfs to this list - it'll only check turfs.
/* This is the proc that starts the crash loop. Maybe log what passes through it?
	-Thooloo
	*/
/datum/controller/subsystem/sunlight/proc/InitializeTurfs(list/targets)
	for (var/z in SSmapping.levels_by_trait(ZTRAIT_STATION))
		for (var/turf/T in block(locate(1,1,z), locate(world.maxx,world.maxy,z)))
			if (T.dynamic_lighting && T.loc:dynamic_lighting)
				T.sunlight_overlay = new /atom/movable/sunlight_overlay(T)
	var/msg = "af loop [GLOB.SUNLIGHT_QUEUE_WORK.len]"
	to_chat(world, "<span class='boldannounce'>[msg]</span>")
	log_world(msg)


/* set sunlight colour */
/datum/controller/subsystem/sunlight/proc/setColour()


	color = list(
		01, 01, 01, 01,
		01, 01, 01, 01,
		01, 01, 01, 01,
		01, 01, 01, 01,
		00, 00, 00, 00
	)

	/* get all variations of corner colours, so we dont have to recalc this */
	/* I couldn't think of a neater way to do this */
	for( var/cr = 0 to 1)
		for( var/cg = 0 to 1)
			for( var/cb = 0 to 1)
				for( var/ca = 0 to 1)
					cornerColour["[cr][cg][cb][ca]"] = \
					list(
						cr, cr, cr, (cr || cg || cb || ca),
						cg, cg, cg, (cr || cg || cb || ca),
						cb, cb, cb, (cr || cg || cb || ca),
						ca, ca, ca, (cr || cg || cb || ca),
						00, 00, 00,  00
					)

/datum/controller/subsystem/sunlight/fire(resumed, init_tick_checks)

	nextBracket()

	MC_SPLIT_TICK_INIT(3)
	if(!init_tick_checks)
		MC_SPLIT_TICK
	var/i = 0
	for (i in 1 to GLOB.SUNLIGHT_QUEUE_WORK.len)
		var/atom/movable/sunlight_overlay/W = GLOB.SUNLIGHT_QUEUE_WORK[i]

		W.check_state()
		GLOB.SUNLIGHT_QUEUE_UPDATE |= W

		if(init_tick_checks)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			break
	if (i)
		GLOB.SUNLIGHT_QUEUE_WORK.Cut(1, i+1)
		i = 0


	if(!init_tick_checks)
		MC_SPLIT_TICK
	for (i in 1 to GLOB.SUNLIGHT_QUEUE_UPDATE.len)
		var/atom/movable/sunlight_overlay/U = GLOB.SUNLIGHT_QUEUE_UPDATE[i]

		U.update_colour()
		if(init_tick_checks)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			break
	if (i)
		GLOB.SUNLIGHT_QUEUE_UPDATE.Cut(1, i+1)
		i = 0


	if(!init_tick_checks)
		MC_SPLIT_TICK
	/* this runs uber slow when we do a unique |= add in the sunlight calc loop, so do it here */
	// GLOB.SUNLIGHT_QUEUE_CORNER = uniqueList(GLOB.SUNLIGHT_QUEUE_CORNER)
	for (i in 1 to GLOB.SUNLIGHT_QUEUE_CORNER.len)
		var/atom/movable/sunlight_overlay/U = GLOB.SUNLIGHT_QUEUE_CORNER[i].sunlight_overlay

		if(!U)
			continue
		
		var/turf/T = U.loc
		if(!T.roof) /* unroofed turfs already are fullbright */
			continue

		U.update_corner()


		if(init_tick_checks)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			break
	if (i)
		GLOB.SUNLIGHT_QUEUE_CORNER.Cut(1, i+1)
		i = 0



/datum/controller/subsystem/sunlight/proc/nextBracket()
	var/Time = station_time()
	var/newTime

	switch (Time)
		if (CYCLE_SUNRISE 	to CYCLE_MORNING - 1)
			newTime = "SUNRISE"
		if (CYCLE_MORNING 	to CYCLE_DAYTIME 	- 1)
			newTime = "MORNING"
		if (CYCLE_DAYTIME 	to CYCLE_AFTERNOON	- 1)
			newTime = "DAYTIME"
		if (CYCLE_AFTERNOON to CYCLE_SUNSET 	- 1)
			newTime = "AFTERNOON"
		if (CYCLE_SUNSET 	to CYCLE_NIGHTTIME - 1)
			newTime = "SUNSET"
		else
			newTime = "NIGHTTIME"

	if (newTime != currentTime)
		currentTime = newTime
		updateLight(currentTime)
		setColour()
		. = TRUE


/datum/controller/subsystem/sunlight/proc/updateLight(newTime)
	
	switch (newTime)
		if ("SUNRISE")
			screenColour = "#ffd1b3"
		if ("MORNING")
			screenColour = "#fff2e6"
		if ("DAYTIME")
			screenColour = "#FFFFFF"
		if ("AFTERNOON")
			screenColour = "#fff2e6"
		if ("SUNSET")
			screenColour = "#ffcccc"
		if("NIGHTTIME")
			screenColour = "#00111a"
	/* for each thing, update the colour */
	for (var/obj/screen/plane_master/lighting/SP in sunlighting_planes)
		SP.color = screenColour

#undef CYCLE_SUNRISE
#undef CYCLE_MORNING
#undef CYCLE_DAYTIME
#undef CYCLE_AFTERNOON
#undef CYCLE_SUNSET
#undef CYCLE_NIGHTTIME
