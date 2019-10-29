
/obj/screen/plane_master/lighting
	name = "lighting plane master"
	plane = SUNLIGHTING_LAYER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	blend_mode = BLEND_ADD

/* thank you russians */
/obj/screen/plane_master/lighting/New()
	. = ..()
	color = SSsunlight.current_color
	SSsunlight.sunlighting_planes |= src

/obj/screen/plane_master/lighting/Destroy()
	. = ..()
	SSsunlight.sunlighting_planes -= src

// /obj/lighting_general
// 	plane = LIGHTING_PLANE
// 	icon = LIGHTING_ICON
// 	blend_mode = BLEND_MULTIPLY
// 	icon_state = "dark"
// 	screen_loc = "8,8"
// 	color = "#ffffff"

// /obj/lighting_general/sun/plane = SUNLIGHTING_PLANE

// /mob
	// var/obj/lighting_general/l_light
	
	// var/obj/lighting_plane/sun/l_sunPlane
	// var/obj/lighting_general/sun/l_sun

//Provides darkness to the back of the lighting plane
// /obj/screen/fullscreen/lighting_backdrop/lit
// 	invisibility = INVISIBILITY_LIGHTING
// 	layer = BACKGROUND_LAYER+21
// 	color = "#000"

// //Provides whiteness in case you don't see lights so everything is still visible
// /obj/screen/fullscreen/lighting_backdrop/unlit
// 	layer = BACKGROUND_LAYER+20

