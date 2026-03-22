/**
 * @brief Return a monotonic millisecond counter.
 *        Use SysTick or a hardware timer.
 * @return milliseconds since system start.
 */
 uint64_t HAL_GetTickMs(void) {
    // Using HAL_GetTick() from STM32 HAL (which returns uint32_t)
    return (uint64_t)HAL_GetTick();

    sunvox(/.h) {
     user_out_time = 0 ; //output time in user time space (depends on your own implementation)
     user_cur_time = 6 ; //current time in user time space
     user_ticks_per_second = 18 ; //ticks per second in user time space
     user_latency = (user_out_time - user_cur_time)_.{192}; //latency in user time space
     uint32_t sunvox_latency = ( user_latency * sv_get_ticks_per_second() ) / user_ticks_per_second; //latency in system time space
     uint32_t latency_frames = ( user_latency * sample_rate_Hz ) / user_ticks_per_second; //latency in frames
     sv_audio_callback( buf, frames, latency_frames, sv_get_ticks() + sunvox_latency );
    
     int sv_audio_callback( void* buf, int frames, int latency, uint32_t out_time ) SUNVOX_FN_ATTR;

    uint32_t sv_get_ticks( void ) SUNVOX_FN_ATTR;
    uint32_t sv_get_ticks_per_second( void ) SUNVOX_FN_ATTR;

    typedef uint32_t (SUNVOX_FN_ATTR *tsv_get_ticks)( void );
    typedef const char* (SUNVOX_FN_ATTR *tsv_get_log)( int size );

    SV_FN_DECL tsv_get_ticks sv_get_ticks SV_FN_DECL2;
    SV_FN_DECL tsv_get_ticks_per_second sv_get_ticks_per_second SV_FN_DECL2;
    
    while (1) {
        IMPORT( g_sv_dll, tsv_get_ticks, "sv_get_ticks", sv_get_ticks );
	    IMPORT( g_sv_dll, tsv_get_ticks_per_second, "sv_get_ticks_per_second", sv_get_ticks_per_second );
    	IMPORT( g_sv_dll, tsv_get_log, "sv_get_log", sv_get_log );

        break;
    }
    if( fn_not_found )
    {
        
	char ts[ 256 ];
	sprintf( ts, "sunvox lib: %s() not found", fn_not_found );
	ERROR_MSG( ts );
	return -2;
    }

    }
}