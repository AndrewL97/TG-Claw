
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
	
	var/turf/source_turf

	var/needs_update = FALSE

	var/datum/lighting_corner/list/affectingCorners /* the opposite of the corner's affecting var, so we know what to turn off/on and update the corresponding corner masters*/

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
	source_turf = T
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


	if (state != 2)
		return /* full bright, not for me sorry */

	/* check if we are globally affected or not */
	var/static/datum/lighting_corner/dummy/dummy_lighting_corner = new
	var/datum/lighting_corner/cr = dummy_lighting_corner
	var/datum/lighting_corner/cg = dummy_lighting_corner
	var/datum/lighting_corner/cb = dummy_lighting_corner
	var/datum/lighting_corner/ca = dummy_lighting_corner

	cr = source_turf.corners[3] || dummy_lighting_corner
	cg = source_turf.corners[2] || dummy_lighting_corner
	cb = source_turf.corners[4] || dummy_lighting_corner
	ca = source_turf.corners[1] || dummy_lighting_corner

	var/fr = cr.sunFalloff
	var/fg = cg.sunFalloff
	var/fb = cb.sunFalloff
	var/fa = ca.sunFalloff

	#if LIGHTING_SOFT_THRESHOLD != 0
	luminosity = max(fr, fg, fb, fa) > LIGHTING_SOFT_THRESHOLD
	#else
	luminosity = max(fr, fg, fb, fa) > 1e-6
	#endif

	color = list(
				fr, fr, fr, ((fr || fg || fb || fa) > 0 ),
				fg, fg, fg, ((fr || fg || fb || fa) > 0 ),
				fb, fb, fb, ((fr || fg || fb || fa) > 0 ),
				fa, fa, fa, ((fr || fg || fb || fa) > 0 ),
				00, 00, 00,  00 )

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
			color = SUNLIGHTING_DARK_MATRIX //get the dark thing
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
	if(oldState != state)
		disableLight()


/atom/movable/sunlight_overlay/proc/getNewState(neighbourLight = FALSE)
	var/setLight = FALSE

	if(!source_turf.roof)
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
	source_turf.roof = !source_turf.roof
	if(!no_update) /* turn light off/on or bugger with colours - update our direct neighbours */
		GLOB.SUNLIGHT_QUEUE_WORK |= src
		
/* we probably shouldn"t be deleted, but clean us up in case */
/atom/movable/sunlight_overlay/Destroy()
	disableLight()
	GLOB.SUNLIGHT_OVERLAYS -= src
	return ..()


/atom/movable/sunlight_overlay/proc/disableLight()
	for(var/datum/lighting_corner/C in affectingCorners)
		LAZYREMOVE(C.globAffect, src)
		C.getSunFalloff()
		GLOB.SUNLIGHT_QUEUE_CORNER += C.masters

/* yoinked from lighting_source - identical save for light_range being GLOB */
#define SUN_FALLOFF(C, T) (1 - CLAMP01(sqrt((C.x - T.x) ** 2 + (C.y - T.y) ** 2 + LIGHTING_HEIGHT) / max(1, GLOB.GLOBAL_LIGHT_RANGE)))

/atom/movable/sunlight_overlay/proc/fuk()



/atom/movable/sunlight_overlay/proc/CalcSunlightSpread()
	var/datum/lighting_corner/C
	var/turf/T
	var/thing			
	var/list/tempMasterList = list() /* to mimimize double ups */
	var/list/cuddlyCorners  = list() /* corners we are currently affecting */

	for(T in view(CEILING(GLOB.GLOBAL_LIGHT_RANGE, 1), source_turf))
		for (thing in T.get_corners(source_turf))
			C = thing
			cuddlyCorners  |= C
			tempMasterList |= C.masters

	/* fix up the lists */
	/* add ourselves and distance from the corner */
	LAZYINITLIST(affectingCorners)
	var/list/L = cuddlyCorners - affectingCorners 
	affectingCorners += L
	for (thing in L)
		C = thing
		LAZYSET(C.globAffect, src, SUN_FALLOFF(C,source_turf))
		if(C.globAffect[src] > C.sunFalloff) /* if are closer than current dist, update the corner */
			C.sunFalloff = C.globAffect[src]		

	L = affectingCorners - cuddlyCorners // Now-gone corners, remove us from the affecting.
	affectingCorners -= L
	for (thing in L)
		C = thing
		LAZYREMOVE(C.globAffect, src)
		C.getSunFalloff()
		tempMasterList |= C.masters /* update the dudes we just removed <<<<<<<<<<<<<<<<<<<<<< */


	GLOB.SUNLIGHT_QUEUE_CORNER += tempMasterList /* update the boys */

#undef SUN_FALLOFF
