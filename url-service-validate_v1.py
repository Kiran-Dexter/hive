import requests
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry
from tabulate import tabulate
import re
import ssl
import socket

# Function to return description for HTTP status codes
def http_status_description(status_code):
    if status_code == 200:
        return "OK: The request was successful."
    elif status_code == 301 or status_code == 302:
        return "Redirect: The requested resource has moved to another URL."
    elif status_code == 400:
        return "Bad Request: The request was invalid or cannot be served."
    elif status_code == 401:
        return "Unauthorized: Authentication is required."
    elif status_code == 403:
        return "Forbidden: Access is forbidden to the requested resource."
    elif status_code == 404:
        return "Not Found: The resource could not be found."
    elif status_code == 500:
        return "Internal Server Error: The server encountered an error."
    else:
        return "Other: Status code " + str(status_code)

# Function to handle retries with exponential backoff
def requests_retry_session(retries=3, backoff_factor=0.3, status_forcelist=(500, 502, 504), session=None):
    session = session or requests.Session()
    retry = Retry(
        total=retries,
        read=retries,
        connect=retries,
        backoff_factor=backoff_factor,
        status_forcelist=status_forcelist,
    )
    adapter = HTTPAdapter(max_retries=retry)
    session.mount('https://', adapter)
    session.mount('http://', adapter)
    return session

# Function to ensure URLs have the correct scheme (http/https)
def ensure_scheme(url):
    if not re.match(r'^https?://', url):
        # Default to https:// if no scheme is provided
        url = 'https://' + url
    return url

# Function to get the IP address of the hostname
def get_ip_address(hostname):
    try:
        return socket.gethostbyname(hostname)
    except Exception as e:
        return f"Failed to resolve IP: {e}"

# Function to get SSL certificate information
def get_ssl_certificate_info(hostname):
    try:
        context = ssl.create_default_context()
        conn = context.wrap_socket(socket.socket(socket.AF_INET), server_hostname=hostname)
        conn.connect((hostname, 443))
        cert = conn.getpeercert()
        issuer = dict(x[0] for x in cert['issuer'])
        common_name = dict(x[0] for x in cert['subject'])['commonName']
        return issuer['organizationName'], common_name
    except Exception as e:
        return "N/A", f"Failed to retrieve certificate: {e}"

# Function to check the endpoint based on its type and follow redirects if needed
def check_endpoint(endpoint):
    ssl_issuer, ssl_cn = "N/A", "N/A"
    ip_address = "N/A"

    # Ensure URL has correct scheme
    endpoint = ensure_scheme(endpoint)
    
    try:
        # Extract the hostname and get IP address
        hostname = re.sub(r"https?://", "", endpoint).split('/')[0]
        ip_address = get_ip_address(hostname)

        # Get SSL information for HTTPS URLs
        if endpoint.startswith("https://"):
            ssl_issuer, ssl_cn = get_ssl_certificate_info(hostname)

        session = requests_retry_session()
        response = session.get(endpoint, timeout=5, allow_redirects=True)

        # Check if the link is reachable
        status_code = response.status_code
        link_status = "Reachable" if status_code in range(200, 400) else "Unreachable"
        description = http_status_description(status_code)

        # If it's a redirect, add more information about the new URL
        if status_code in [301, 302]:
            description += f" Redirected to: {response.url}"

        return (endpoint, link_status, ip_address, status_code, description, ssl_issuer, ssl_cn)

    except requests.exceptions.Timeout:
        return (endpoint, "Timeout", ip_address, "N/A", "The request timed out.", ssl_issuer, ssl_cn)
    except requests.exceptions.ConnectionError:
        return (endpoint, "Not Reachable", ip_address, "N/A", "Failed to connect to the server.", ssl_issuer, ssl_cn)
    except requests.exceptions.RequestException as e:
        return (endpoint, "Not Reachable", ip_address, "N/A", f"An error occurred: {e}", ssl_issuer, ssl_cn)

# Function to read URLs from a file
def read_urls_from_file(filename):
    try:
        with open(filename, "r") as file:
            urls = [line.strip() for line in file.readlines() if line.strip()]
        return urls
    except FileNotFoundError:
        print(f"Error: The file {filename} was not found.")
        return []

# Collect results and output the table
def run_checks():
    urls = read_urls_from_file('urls.txt')  # Read URLs from the 'urls.txt' file
    if not urls:
        print("No URLs to check.")
        return

    results = [check_endpoint(endpoint) for endpoint in urls]

    # Create table headers and rows
    headers = ["Endpoint", "Link Status", "IP Address", "HTTP Status Code", "Description", "SSL Issuer", "SSL CN"]
    table = tabulate(results, headers, tablefmt="grid")

    # Save the output to a file
    with open('output.txt', 'w') as f:
        f.write(table)

    print("Results have been written to output.txt")

if __name__ == "__main__":
    run_checks()
