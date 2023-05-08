# ROYGBIV

Like a prism... get it?

`prism` is a CLN plugin that creates bolt12 offers representing a lightning prism.

## Usage:

ROYGBIV adds two RPC methods. One to _create_ prisms, and the other to _list_ them.

### Creating a prism:

- **method**: _prism_
- **params**: _label_ as a string and _members_ as an array

```
lightning-cli prism label="string" members='[{"name": "node_pubkey", "destination": "node_pubkey", "split": 1 <= num <= 1000}]'
```

Returns the bolt12 offer:

```
{
   "offer_id": "eb9479c5f517d0194b49cb3370d87211b9548134ee2d3df244f3fd16d3922a82",
   "active": true,
   "single_use": false,
   "bolt12": "lno1qgsqvgnwgcg35z6ee2h3yczraddm72xrfua9uve2rlrm9deu7xyfzrc2qunnzwfcxq6jw93pq05mpwn9adpag8pw6jzefwyh38zte0p73zf9lfkc8mvwq6gm9ekvz",
   "used": false,
   "created": true
}

```

| Check out the [create_prism](https://github.com/farscapian/clams-app-docker/blob/main/channel_templates/create_prism.sh) script it you're running the Clams stack with ROYGBIV

#### Key things to note:

- splits get normalized to relative sat amounts

For example:

```
lightning-cli prism label="string" members='[{"name": "alice", "destination": "alice_pubkey", "split": 1}, {"name": "bob", "destination": "bob_pubkey", "split": 1}, {"name": "carol", "destination": "carol_pubkey", "split": 1}]'
```

The above equally distributes each payment to Alice, Bob, and Carol. . . they each get 33%.

Likewise, if Carol's split was changed to 2, then Alice --> 25%, Bob --> 25%, Carol --> 50%

- split only accepts integers 1 - 1000
- Currently **only supports recipients of prism payments with keysend enabled**

### Listing prisms

- **method**: _listprisms_

```
lightning-cli listprisms
```

Returns an array of prism metadata:

```
[
   {
      "label": "'15875'",
      "bolt12": "lno1qgsqvgnwgcg35z6ee2h3yczraddm72xrfua9uve2rlrm9deu7xyfzrc2qunnzdfcxu6jw93pqwmglk2a6d6lxdpqcj4ewlmrtpuseguafyh2l48y6fnav5rqgewvj"
      "members": [
         {
            "name": "carol",
            "destination": "0251b497f566aa3308a3b70f5619d2585afe7166c26137ff769f1dc7547e1cfe0d",
            "split": 1
         },
      ]
   }
]

```
