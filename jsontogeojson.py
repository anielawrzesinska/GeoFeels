import json
import ast
import re
import glob

folder='D:\\inzynier\\data\\11_2019\\data\\*.json'
lista_plikow=glob.glob(folder)
for plik in lista_plikow:
    # Tweets are stored in "fname"
    with open(plik, 'r', encoding='utf-8') as f:
        geo_data = {
            "type": "FeatureCollection",
            "features": []
        }
        for line in f:
            tweet = json.loads(line)
            try:
                if tweet['coordinates']:
                    geo_json_feature = {
                        "type": "Feature",
                        "geometry": tweet['coordinates'],
                        "properties": {
                            "text": tweet['extended_tweet']['full_text'],
                            "created_at": tweet['created_at']
                        }
                    }
                    geo_data['features'].append(geo_json_feature)
            except KeyError:
                continue
        
    

    # Save geo data
    with open(plik[-19:], 'w', encoding='utf8') as fout:
        fout.write(json.dumps(geo_data, indent=4,ensure_ascii=False))

