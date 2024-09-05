import requests
import re
from bs4 import BeautifulSoup
from tabulate import tabulate

# URL validation pattern
url_pattern = re.compile(r'((http|https)://)(www\.)?'
                         r'[a-zA-Z0-9@:%._\+~#?&//=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%._\+~#?&//=]*)')

# Function to load URLs from a file
def load_urls_from_file(file_path):
    with open(file_path, 'r') as file:
        urls = [line.strip() for line in file if line.strip()]
    return urls

# Function to check if the URL is valid
def is_valid_url(url):
    return re.search(url_pattern, url) is not None

# Function to check if a site requires authentication
def requires_authentication(response):
    return response.status_code == 401  # HTTP 401 Unauthorized

# Function to check if a site has a login form
def has_login_form(response):
    soup = BeautifulSoup(response.text, 'html.parser')
    form = soup.find('form')
    if form and ('password' in str(form).lower()):
        return True
    return False

# Function to check if a site is dead
def is_dead_site(url):
    try:
        response = requests.get(url, timeout=10)
        return response.status_code >= 400
    except requests.exceptions.RequestException:
        return True

# Function to check if an API is alive
def is_valid_api(url):
    try:
        response = requests.get(url, timeout=10)
        if response.status_code == 200:
            return True
        return False
    except requests.exceptions.RequestException:
        return False

# General function to check if it's any image registry (Docker, Harbor, Quay, etc.)
def is_image_registry(url):
    registry_endpoints = [
        '/v2/',  # Docker
        '/api/v2.0/',  # Harbor
        '/api/v1/',  # Quay
        '/v1/_catalog',  # Other registries might support catalog API
    ]
    for endpoint in registry_endpoints:
        try:
            response = requests.get(f'{url}{endpoint}', timeout=10)
            if response.status_code == 200:
                return True
        except requests.exceptions.RequestException:
            pass
    return False

# Main validation function
def validate_urls(urls):
    results = []
    
    for url in urls:
        status = "Valid"
        
        if not is_valid_url(url):
            status = "Invalid URL format"
        elif is_dead_site(url):
            status = "Site is dead"
        else:
            try:
                response = requests.get(url, timeout=10)
                if requires_authentication(response):
                    status = "Requires authentication (HTTP 401)"
                elif has_login_form(response):
                    status = "Contains a login form"
                elif is_valid_api(url):
                    status = "API is valid and reachable"
                elif is_image_registry(url):
                    status = "Image registry is valid"
                else:
                    status = "Site is reachable"
            except Exception as e:
                status = f"Error: {e}"

        # Append result to the list
        results.append([url, status])
    
    return results

# Function to save the results in a formatted table in a file
def save_results_to_file(results):
    table = tabulate(results, headers=["URL", "Status"], tablefmt="pretty")
    with open("url_validation_results.txt", "w") as file:
        file.write(table)

# Run the process
file_path = 'urls.txt'  # Path to the file with URLs
urls = load_urls_from_file(file_path)
results = validate_urls(urls)
save_results_to_file(results)
