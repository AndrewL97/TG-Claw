
/* turf fuckery */
/turf/var/tmp/atom/movable/sunlight_overlay/sunlight_overlay /* our sunlight overlay */

/turf/var/roof = TRUE //TODO: Make this into a /datum/roof/[metal/wood/unbreakableStone] object, with NULL being no roof

/* list o" turfs that have no roofs on init - this is pretty quick 'n' dirty, needs a better method(?) */
/turf/open/indestructible/ground/outside/roof = FALSE


/atom/movable/sunlight_overlay
	name = ""
	mouse_opacity = 0
	anchored = 1
	icon          		=  LIGHTING_ICON
	// icon_state    		=  "transparent"
	plane 				=  SUNLIGHTING_PLANE //LIGHTING_PLANE
	layer 				=  SUNLIGHTING_LAYER //ABOVE_LIGHTING_LAYER
	invisibility 		=  INVISIBILITY_LIGHTING
	color 				=  SUNLIGHTING_BASE_MATRIX
	blend_mode    		=  BLEND_ADD

	var/state = 1
	var/turf/list/neighbourTurfs = list() //so we dont have to call AdjacentTurfs a billion times


	var/cr = 0
	var/cg = 0
	var/cb = 0
	var/ca = 0

	var/needs_update = FALSE

	var/datum/lighting_corner/list/affectingCorners = list() /* the opposite of the corner's affecting var, so we know what to turn off/on and update the corresponding corner masters*/

/atom/movable/sunlight_overlay/Initialize()

	// doesn"t need special init
	flags_1 |= INITIALIZED_1
	GLOB.SUNLIGHT_OVERLAYS += src
	// getNeighbouringSunlightOverlays()
	return INITIALIZE_HINT_NORMAL

/atom/movable/sunlight_overlay/Destroy()
	return QDEL_HINT_LETMELIVE
	. = ..()

/atom/movable/sunlight_overlay/New(var/atom/loc, var/no_update = FALSE)
	var/turf/T = loc //If this runtimes atleast we"ll know what"s creating overlays outside of turfs.
	if(!T.sunlight_overlay)
		. = ..()
		verbs.Cut()
		// total_sunlight_overlays++
		T.sunlight_overlay = src
		neighbourTurfs = RANGE_TURFS(1, T)
		// overlays += GLOB.globSunBackdrop
	else
		qdel(src)

/* written out as painful steps for more faster zoom - thanks lighting_overlay										  */
/* essentially, we make this a big coloured square, but don"t light up the corners lit by neighbouring sunlight turfs */
/atom/movable/sunlight_overlay/proc/update_corner()
	var/turf/T = loc

	/* wether or not we need to compensate */
	cr = ((T.corners[3] && T.corners[3].globAffect.len) ? 1 : 0) /* check if we are globally affected or not */
	cg = ((T.corners[2] && T.corners[2].globAffect.len) ? 1 : 0)
	cb = ((T.corners[4] && T.corners[4].globAffect.len) ? 1 : 0)
	ca = ((T.corners[1] && T.corners[1].globAffect.len) ? 1 : 0)

	/* no corners (for whatever reason, so turn off...or on, most of the time) */
	luminosity = (cr || cg || cb || ca)
	color = SSsunlight.cornerColour["[cr][cg][cb][ca]"]

/* We have three states as a sunlight overlay */
/* 1 - we are unroofed and fully surrounded by state 1 or 4 sunlight overlays, so we are simple coloured square   					*/
/* 2 - we are roofed, so we check our corners to pick up light emitted by state 3 turfs						     					*/
/* 3 - we are beside roofed turfs, so we hide ourselves and emit light, to light up the roofed turfs (through windows, doors, etc.) */
/* we use a super simple dview loop, and flag corners on or off for sunlight, rather than dealing with colour calculation, because  */
/* we are all the same colour, no need to calculate. It would be ideal to combine this object with the lighting_overlay, to save    */
/* the memory of storing twice as many overlays, but I cant get the colour mixing right												*/

/atom/movable/sunlight_overlay/proc/update_colour()
	switch(state)
		if(1)
			// icon_state = "transparent"
			color = SSsunlight.color
			luminosity = 1
		if(2)
			// icon_state = "dark"
			color = SSsunlight.cornerColour["0000"] //get the dark thing
			luminosity = 0
		if(3)
			CalcSunlightSpread()
			// icon_state = "sunlight"
			color = SSsunlight.color
			luminosity = 3

			// blend_mode = BLEND_SUBTRACT
			
/atom/movable/sunlight_overlay/proc/check_state()
	var/oldState = state
	getNewState()
	if(oldState == 2 && state != oldState)
		disableLight()


/atom/movable/sunlight_overlay/proc/getNewState(neighbourLight = FALSE)
	var/turf/T = loc
	var/setLight = FALSE

	if(!T.roof)
		for(var/turf/CT in neighbourTurfs)
			if(!CT.roof) /* update our unroofed, unlighty friends */
			else
				setLight = TRUE /* we have a roofed neighbour, so turn on a light so we can colour our friends */
		if(setLight) /* turn on the light, and set our colour to black so we dont double up on pretty colours */
			state = 3
			return
		else
			state = 1
		return
	else /* roofed, so turn off the lights*/
		state = 2

/* turn roof off/on, update the nieghbours so they turn lights off/on */
/atom/movable/sunlight_overlay/proc/toggleRoof(no_update = FALSE) /* remove once complete, so this isn"t silly */
	var/turf/T = loc
	T.roof = !T.roof
	if(!no_update) /* turn light off/on or bugger with colours - update our direct neighbours */
		GLOB.SUNLIGHT_QUEUE_WORK |= src
		
/* we probably shouldn"t be deleted, but clean us up in case */
/atom/movable/sunlight_overlay/Destroy()
	GLOB.SUNLIGHT_OVERLAYS -= src
	return ..()


/atom/movable/sunlight_overlay/proc/disableLight()
	for(var/datum/lighting_corner/C in affectingCorners)
		C.globAffect -= src;
		GLOB.SUNLIGHT_QUEUE_CORNER += C.masters

/atom/movable/sunlight_overlay/proc/CalcSunlightSpread()
	var/source_turf = src.loc
	var/datum/lighting_corner/C
	var/turf/T
	var/thing			
	for(T in view(CEILING(GLOB.GLOBAL_LIGHT_RANGE, 1), source_turf))
		for (thing in T.get_corners(source_turf))
			C = thing
			C.globAffect |= src;
			affectingCorners |= C
			GLOB.SUNLIGHT_QUEUE_CORNER += C.masters /* update the boys */
			

