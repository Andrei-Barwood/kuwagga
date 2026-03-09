#!/usr/bin/env zsh
set -euo pipefail

# Reference snippet (C/libcurl) kept for documentation purposes.
cat <<'C_SNIPPET'
int main(void) {
    CURL *curl = curl_easy_init();
    if (curl) {
        curl_easy_setopt(curl, CURLOPT_URL, "https://icloud.com");
        /* leave nagle enabled */
        curl_easy_setopt(curl, CURLOPT_TCP_NODELAY, 0L);
        curl_easy_perform(curl);
    }
}
C_SNIPPET
