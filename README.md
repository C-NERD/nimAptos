## nimAptos
Aptos sdk for nimlang.
check out the the aptos foundation github profile [here](https://github.com/aptos-labs)

## Installation
`nimble install aptos`
Or clone this repo and run `nimble install` in it's root directory

## Examples
Check `./examples`
or `./src/aptos.nim`
or `./src/aptos/sugars.nim`
you'll be required to set enviromental variables in order to properly run the examples.
The variables names can be found in the code of the examples

## Docs
Check out docs at [docs](https://rawcdn.githack.com/C-NERD/libDocs/3f86751a5840db24d6ab74ff87278eabb9998096/nimaptos_docs/aptos.html).

## RoadMap For Now
- Code cleaning
- Bug fixes
- Improve module logging
- Provide pragma for proc errors raised
- Implement code to allow passing of more options to http client
- Proper demarcation of vanila browser js compartable modules
- Implement Bcs serialization and deSerialization for all sendable datatypes
- Implement Bcs requests
- Implement ed25519 12 word recovery phrase
- Implement secp256k1_ecdsa keypair

## Contribution
If you wish to contribute, please fork the devel branch and perform pull requests to devel. When a new release is to drop, all updates to devel will be pushed to main
