// Enhanced kern.osversion handling with privacy controls
static int
sysctl_osversion_privacy_handler(struct sysctl_oid *oidp, void *arg1, 
                                int arg2, struct sysctl_req *req) {
    char version_buffer[256];
    char *sanitized_version;
    int error;
    
    // Check privacy settings
    if (privacy_settings.mask_build_version) {
        sanitized_version = sanitize_build_version_string(osversion);
        strlcpy(version_buffer, sanitized_version, sizeof(version_buffer));
    } else {
        strlcpy(version_buffer, osversion, sizeof(version_buffer));
    }
    
    error = sysctl_handle_string(oidp, version_buffer, 
                                sizeof(version_buffer), req);
    return error;
}

static char *
sanitize_build_version_string(const char *original) {
    static char sanitized[256];
    char *build_start, *build_end;
    
    strlcpy(sanitized, original, sizeof(sanitized));
    
    // Find and replace build number with generic identifier
    build_start = strstr(sanitized, "Build ");
    if (build_start) {
        build_end = strchr(build_start, ')');
        if (build_end) {
            snprintf(build_start, (build_end - build_start) + 1, 
                    "Build Generic)");
        }
    }
    
    return sanitized;
}
