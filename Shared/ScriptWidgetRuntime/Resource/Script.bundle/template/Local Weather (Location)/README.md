# Weather forecast

Open **Records & Configuration** to save a city, latitude/longitude and Celsius or Fahrenheit. City search uses Apple Maps; you can also enter coordinates directly. On iPhone, optionally enable current location. If location is unavailable, the saved city is used. The script never requests permission itself.

Weather is a forecast from MET Norway, not a live observation. Requests send coordinates rounded to two decimal places to api.met.no. See https://api.met.no/doc/TermsOfService and https://api.met.no/doc/License. Weather data: MET Norway, CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). Icons use system SF Symbols, not the provider’s artwork.

The bounded local cache keeps at most four places (at most one current-location entry). Expiry and conditional requests follow response headers, with a minimum refresh interval and retry backoff. Cached forecasts show their source age and refresh failures. Data older than 24 hours or without a nearby forecast point is unavailable; temperatures are never invented. Future timeline projections do not fetch or change storage. System scheduling can delay refresh.

A record backup contains saved configuration only; transient forecast/location cache is excluded. Exporting the script package and exporting records are separate operations.

Optional instance parameter: `latitude,longitude,City`, or a JSON object containing `city`, `latitude`, `longitude`, `useLocation`, and/or `unit` (`c` or `f`). Instance parameters override saved settings.

Web Studio shows editable synthetic Mock responses, not current weather. The bundled preview is an explicitly synthetic native-rendered example.
