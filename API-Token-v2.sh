#!/bin/bash

# Set the API endpoint URL
api_url="https://example.com/api/data"

# Set the API token value
api_token="your-api-token-value"

# Make the API request with curl and save the response to a file
response=$(curl -H "Authorization: Bearer $api_token" $api_url)

# Check the response status code
http_status=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $api_token" $api_url)

if [ $http_status -eq 200 ]
then
  # Extract the URI from the response and create the output file name
  uri=$(echo $response | jq -r '.uri')
  output_file=$(basename $uri)

  # Add the URI to the API endpoint URL
  api_url="$api_url/$uri"

  # Make the API request with the updated URL and save the response to a file
  curl -H "Authorization: Bearer $api_token" -o $output_file $api_url

  # Check the response status code
  http_status=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $api_token" $api_url)

  if [ $http_status -eq 200 ]
  then
    echo "API request successful. Data has been dumped to $output_file"
  else
    echo "API request failed with status code $http_status"
  fi
else
  echo "API request failed with status code $http_status"
fi
