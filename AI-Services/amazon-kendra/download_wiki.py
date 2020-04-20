import requests
from bs4 import BeautifulSoup
import tqdm

for i in tqdm.tqdm(range(1000)):
    text_str = requests.get("http://en.wikipedia.org/wiki/Special:Random").text
    soup = BeautifulSoup(text_str, 'html.parser')
    [s.extract() for s in soup(['style', 'script', '[document]', 'head', 'title'])]
    page_text = soup.get_text()

    with open(f"file_{i}.txt", "w") as f:
        f.write(page_text)
