#!/usr/bin/env bash
set -euo pipefail;

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
project_dir="$(cd "$script_dir/.." && pwd)";
output_dir="${VISITED_PLACES_DIR:-$project_dir/static/visited_places}";
search_url="${NOMINATIM_SEARCH_URL:-https://nominatim.openstreetmap.org/search}";
user_agent="${NOMINATIM_USER_AGENT:-my-blog-visited-places/1.0 (https://blog.nekoid.cc)}";
query='';
name_override='';
format='geojson';
structured_args=();
extra_args=();
structured_count=0;
response_file='';
output_tmp='';

if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  printf 'curl and jq are required.\n' >&2;
  exit 1;
fi;

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      printf '%s\n' \
        'Usage: scripts/add_visited_place.sh --query "name, place" [options]' \
        '   or: scripts/add_visited_place.sh --city NAME --country NAME [options]' \
        '' \
        'Query: --query, or any structured fields: --amenity --street --city --county --state --country --postalcode' \
        'Options: --format geojson (only), --name DISPLAY_NAME, --param KEY=VALUE (repeatable)' \
        'Prompts for one result and writes COUNTRYCODE_Place_Name.json to static/visited_places/.' \
        'Environment: NOMINATIM_USER_AGENT, NOMINATIM_SEARCH_URL, VISITED_PLACES_DIR.';
      exit 0;
      ;;
    --query|--name|--format|--amenity|--street|--city|--county|--state|--country|--postalcode|--param)
      if [[ $# -lt 2 || -z "$2" ]]; then
        printf 'Missing value for %s.\n' "$1" >&2;
        exit 2;
      fi;
      option="$1";
      value="$2";
      case "$option" in
        --query) query="$value"; ;;
        --name) name_override="$value"; ;;
        --format) format="$value"; ;;
        --param)
          if [[ "$value" != *=* ]]; then
            printf '%s\n' '--param requires KEY=VALUE.' >&2;
            exit 2;
          fi;
          key="${value%%=*}";
          value="${value#*=}";
          if [[ -z "$value" ]]; then
            printf 'Empty value for parameter %s.\n' "$key" >&2;
            exit 2;
          fi;
          case "$key" in
            limit)
              if [[ ! "$value" =~ ^[0-9]{1,2}$ ]] || (( 10#$value < 1 || 10#$value > 40 )); then
                printf 'limit must be between 1 and 40.\n' >&2;
                exit 2;
              fi;
              ;;
            addressdetails|polygon_geojson)
              if [[ "$value" != 1 ]]; then
                printf '%s must be 1 to save a map location.\n' "$key" >&2;
                exit 2;
              fi;
              ;;
            bounded|extratags|namedetails|entrances|dedupe|polygon_kml|polygon_svg|polygon_text|debug)
              if [[ "$value" != 0 && "$value" != 1 ]]; then
                printf '%s must be 0 or 1.\n' "$key" >&2;
                exit 2;
              fi;
              if [[ "$value" == 1 && "$key" =~ ^(polygon_kml|polygon_svg|polygon_text|debug)$ ]]; then
                printf '%s=1 is incompatible with a GeoJSON map import.\n' "$key" >&2;
                exit 2;
              fi;
              ;;
            featureType)
              if [[ ! "$value" =~ ^(country|state|city|settlement)$ ]]; then
                printf 'Invalid featureType: %s.\n' "$value" >&2;
                exit 2;
              fi;
              ;;
            layer)
              if [[ ! "$value" =~ ^(address|poi|railway|natural|manmade)(,(address|poi|railway|natural|manmade))*$ ]]; then
                printf 'Invalid layer list: %s.\n' "$value" >&2;
                exit 2;
              fi;
              ;;
            countrycodes)
              if [[ ! "$value" =~ ^[A-Za-z]{2}(,[A-Za-z]{2})*$ ]]; then
                printf 'countrycodes must be comma-separated two-letter codes.\n' >&2;
                exit 2;
              fi;
              ;;
            viewbox)
              if [[ ! "$value" =~ ^-?[0-9]+(\.[0-9]+)?,-?[0-9]+(\.[0-9]+)?,-?[0-9]+(\.[0-9]+)?,-?[0-9]+(\.[0-9]+)?$ ]]; then
                printf 'viewbox must have four comma-separated coordinates.\n' >&2;
                exit 2;
              fi;
              ;;
            polygon_threshold)
              if [[ ! "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                printf 'polygon_threshold must be a nonnegative number.\n' >&2;
                exit 2;
              fi;
              ;;
            email)
              if [[ ! "$value" == *@*.* ]]; then
                printf 'email must be an email address.\n' >&2;
                exit 2;
              fi;
              ;;
            accept-language|include|exclude|exclude_place_ids) ;;
            json_callback)
              printf 'json_callback is incompatible with a GeoJSON map import.\n' >&2;
              exit 2;
              ;;
            format|q|amenity|street|city|county|state|country|postalcode)
              printf 'Use the dedicated --%s option instead of --param.\n' "$key" >&2;
              exit 2;
              ;;
            *)
              printf 'Unsupported Nominatim Search parameter: %s.\n' "$key" >&2;
              exit 2;
              ;;
          esac;
          extra_args+=(--data-urlencode "$key=$value");
          ;;
        *)
          structured_args+=(--data-urlencode "${option#--}=$value");
          structured_count=$((structured_count + 1));
          ;;
      esac;
      shift 2;
      ;;
    *)
      printf 'Unknown option: %s. Use --help for usage.\n' "$1" >&2;
      exit 2;
      ;;
  esac;
done;

if [[ "$format" != geojson ]]; then
  printf 'Only --format geojson can be saved by this map.\n' >&2;
  exit 2;
fi;
if [[ -n "$query" && "$structured_count" -gt 0 ]]; then
  printf 'Use either --query or structured fields, not both.\n' >&2;
  exit 2;
fi;
if [[ -z "$query" && "$structured_count" -eq 0 ]]; then
  printf 'Provide --query or at least one structured field.\n' >&2;
  exit 2;
fi;
if [[ ! -d "$output_dir" ]]; then
  printf 'Visited-places directory does not exist: %s.\n' "$output_dir" >&2;
  exit 2;
fi;
if [[ ! "$search_url" == https://* && ! "$search_url" == http://127.0.0.1:* && ! "$search_url" == http://localhost:* ]]; then
  printf 'NOMINATIM_SEARCH_URL must use HTTPS (or local HTTP for testing).\n' >&2;
  exit 2;
fi;
if [[ -z "$user_agent" || "$user_agent" == *$'\n'* || "$user_agent" == *$'\r'* ]]; then
  printf 'NOMINATIM_USER_AGENT must identify the application on one line.\n' >&2;
  exit 2;
fi;

response_file="$(mktemp)";
trap 'if [[ -n "$response_file" ]]; then rm -f "$response_file"; fi; if [[ -n "$output_tmp" ]]; then rm -f "$output_tmp"; fi;' EXIT;
query_args=();
if [[ -n "$query" ]]; then
  query_args+=(--data-urlencode "q=$query");
else
  query_args+=("${structured_args[@]}");
fi;

# Nominatim requires an identifying User-Agent; this manual command makes one request per run.
if ! curl --fail-with-body --silent --show-error --get --max-time 30 \
  --user-agent "$user_agent" --output "$response_file" \
  --data-urlencode 'format=geojson' --data-urlencode 'polygon_geojson=1' \
  --data-urlencode 'addressdetails=1' "${query_args[@]}" "${extra_args[@]+"${extra_args[@]}"}" "$search_url"; then
  printf 'Nominatim search failed. No file was added.\n' >&2;
  exit 1;
fi;
if ! jq -e '.type == "FeatureCollection" and (.features | type == "array")' "$response_file" >/dev/null 2>&1; then
  printf 'Nominatim did not return a valid GeoJSON FeatureCollection.\n' >&2;
  exit 1;
fi;

result_count="$(jq -r '.features | length' "$response_file")";
if [[ "$result_count" -eq 0 ]]; then
  printf 'No locations matched the search.\n' >&2;
  exit 1;
fi;
jq -r '.features | to_entries[] | "\(.key + 1)) \(.value.properties.display_name // .value.properties.name // "Unnamed") [\(.value.geometry.type // "no geometry")]"' "$response_file";
printf 'Select a location [1-%s]: ' "$result_count" >&2;
if ! IFS= read -r selection || [[ ! "$selection" =~ ^[0-9]{1,2}$ ]] || (( 10#$selection < 1 || 10#$selection > result_count )); then
  printf 'Invalid selection. No file was added.\n' >&2;
  exit 2;
fi;
index=$((10#$selection - 1));
if ! jq -e --argjson index "$index" '.features[$index] | .type == "Feature" and (.geometry.type == "Polygon" or .geometry.type == "MultiPolygon") and (.geometry.coordinates | type == "array" and length > 0)' "$response_file" >/dev/null; then
  printf 'The selected result has no polygon geometry, so the current map cannot display it.\n' >&2;
  exit 2;
fi;

country_code="$(jq -r --argjson index "$index" '.features[$index].properties.address.country_code // empty' "$response_file")";
if [[ ! "$country_code" =~ ^[A-Za-z]{2}$ ]]; then
  printf 'The selected result has no two-letter address country code.\n' >&2;
  exit 2;
fi;
country_code="$(printf '%s' "$country_code" | tr '[:lower:]' '[:upper:]')";
place_name="$name_override";
if [[ -z "$place_name" ]]; then
  place_name="$(jq -r --argjson index "$index" '(.features[$index].properties.name // .features[$index].properties.display_name // "") | split(",")[0] | gsub("^ +| +$"; "")' "$response_file")";
fi;
if [[ "$place_name" == *'<'* || "$place_name" == *'>'* ]]; then
  printf 'The place name contains HTML markup and cannot be shown safely by the current map.\n' >&2;
  exit 2;
fi;
slug="$(jq -nr --arg name "$place_name" '$name | gsub("[^[:alnum:]]+"; "_") | gsub("^_+|_+$"; "") | .[0:80]')";
if [[ -z "$slug" ]]; then
  printf 'The selected result has no usable place name. Use --name.\n' >&2;
  exit 2;
fi;
target="$output_dir/${country_code}_${slug}.json";
if [[ -e "$target" ]]; then
  printf 'Location file already exists: %s.\n' "$target" >&2;
  exit 2;
fi;

# Keep the API attribution and the selected feature, with a name usable by the map popup.
output_tmp="$(mktemp "$output_dir/.visited_place.XXXXXX")";
jq --argjson index "$index" --arg name "$place_name" \
  '{type: "FeatureCollection", licence: (.licence // "Data © OpenStreetMap contributors, ODbL 1.0. https://osm.org/copyright"), features: [(.features[$index] | .properties.name = $name)]}' \
  "$response_file" > "$output_tmp";
if ! jq -e '.type == "FeatureCollection" and (.features | length == 1)' "$output_tmp" >/dev/null; then
  printf 'Could not create the GeoJSON location file.\n' >&2;
  exit 1;
fi;
chmod 644 "$output_tmp";
if ! ln "$output_tmp" "$target"; then
  printf 'Location file already exists or cannot be written: %s.\n' "$target" >&2;
  exit 1;
fi;
printf 'Added %s\n' "$target";
