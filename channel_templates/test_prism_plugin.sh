#! /bin/bash

echo "================================"
echo "Testing the prism plugin... one moment please"

# lets create a prism
prism=$(./create_prism.sh 2>&1)


#make sure there were no errors in the createprism script
if [[ $? -ne 0 ]]; then
  echo "Error: Failed to create Prism offer"
  echo "$prism"
  exit 1
fi


# now make sure it has the expected output
offer_id=$(echo "$prism" | jq -r '.offer_id')
bolt12=$(echo "$prism" | jq -r '.bolt12')

if ! [[ "$offer_id" =~ ^[0-9a-f]{64}$ ]] && [[ "$bolt12" =~ ^[a-z0-9]+$ ]]; then
  echo "Error: createprism returned something weird"
  echo "$prism"
fi


#now check that list prisms works
prisms_list=$(lncli --id=1 listprisms 2>&1)

if [[ $? -ne 0 ]]; then
  echo "Error: listprisms failed..."
  echo "$prisms_list"
fi

num_prisms=$(echo "$prisms_list" | jq length)

if [[ $num_prisms -lt 1 ]]; then
  echo "Error: something is wrong with the list prisms method"
  exit 1
fi


echo -e "\033[1A\033[2K"
echo "All prism plugin tests passed"


