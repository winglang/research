#!/bin/bash

dir="xmls"
inbox="s3://inbox-c88430b8-20230426222152018000000005"

for publisher in "${dir}"/*; do
  if [ -d "${publisher}" ]; then
    publisher_name=$(basename "${publisher}")
    for file in "${publisher}"/*; do
      if [ -f "${file}" ]; then
        file_name=$(basename "${file}")
        aws s3 cp "${dir}/${publisher_name}/${file_name}" "${inbox}/${publisher_name}/${file_name}"
      fi
    done
  fi
done