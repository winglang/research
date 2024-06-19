import json
import base64
from wing import *
from io import BytesIO
from PIL import Image


destination_bucket = "media-app-resized-image"
exclude_keys = {'cover/', 'post/', 'profile/'}

# Custom Image Size
image_sizes = {
    'cover': (820, 160),
    'profile': (170, 170),
    'post': (1080, 1080)
}

def resizer(img, key):
    # image_type = key.split("/")[0]
    # if image_type in image_sizes:
    resized_image = img.resize(image_sizes['cover'])
    temp_buffer = BytesIO()
    resized_image.save(temp_buffer,format=img.format)
    resized_bytes = temp_buffer.getvalue()
    print("herrr1111")
    print(resized_bytes)
    lifted("media-app-resized-image").put(key, base64.b64encode(resized_bytes))

    # client.put_object(Body=resized_bytes, Bucket=destination_bucket, Key=key)
    # print("hello1111")
    # print(img)
    # image64 = base64.b64encode(img)
    # print("hello2222")
    # print(image64)

def download_image(bucket_name, key):
    response = lifted(bucket_name).get(key)
    return response

def lambda_handler(event, context):
  print(event)
  try:
    print("line 33")
    print(event)
    key = event['payload']['key'];  
    source_bucket = 'media-app-initial-image';
            
    if key not in exclude_keys:
      print("here 1")
      print(source_bucket)
      print(key)
      image_content = download_image(source_bucket, key)
      print("here 1234")
      print(image_content)
      with Image.open(BytesIO(base64.b64decode(image_content))) as img:
        img.format
        resizer(img, key)
        
  except Exception as exception:
      print(exception)