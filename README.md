# My Blog

A multilingual personal blog built with Hugo and the PaperMod theme.

## Installation and environment

Install Hugo Extended 0.167.0 or newer and Go. Adding map locations also requires `curl` and `jq`. Fetch the theme submodule:

```sh
git submodule update --init --recursive
hugo server --buildDrafts
```

No environment variables are required for local development.

## Features

- English and Chinese posts with the PaperMod theme.
- A GeoJSON map with clickable regions and location pins.

## Usage

Build the site with `hugo`. To preview draft posts, run `hugo server --buildDrafts` and open `/post/traveling/`.

To include a map in a post, use the shortcode with a directory of GeoJSON files:

```text
{{< render_map id="visited_places" dir="/visited_places" style="minimal" >}}
```

The `id` must be unique on the page. `src` accepts a comma-separated list of GeoJSON URLs as an alternative to `dir`.

### Add a visited place

Run the importer with a free-form name or structured search fields. It lists the matches and asks you to choose one:

```sh
scripts/add_visited_place.sh --query 'Kyoto, Japan' --param countrycodes=jp
scripts/add_visited_place.sh --city Kyoto --country Japan --param featureType=city
```

The script saves a selected polygon as `COUNTRYCODE_Place_Name.json` in `static/visited_places/` and refuses to overwrite an existing file.

## License

PaperMod theme and map data retain their own licenses and attribution.
