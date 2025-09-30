int main(void) {
	CURL *curl = curl_easy_init();
	if(curl) {
		curl_easy_setopt(curl, CURLOPT_URL, "https://icloud.com");
		/* leave nagle enabled */
		curl_easy_setopt(curl, CURLOP_TCP_NODELAY, 0);
		curl_easy_perform(curl);
	}
}