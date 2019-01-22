const RequestableToken = artifacts.require('./RequestableToken.sol');

const Symbol = 'RBG'
const Rootchain = '0x880ec53af800b5cd051531672ef4fc4de233bd5d'

module.exports = function (deployer) {
  deployer.deploy(RequestableToken, Symbol, Rootchain);
};
