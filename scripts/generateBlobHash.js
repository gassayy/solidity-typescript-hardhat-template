const { ethers } = require("hardhat");

async function main() {
  // Example data to hash
  const data = "Hello, Hardhat!";
  
  // Convert the data to a byte array
  const dataBytes = ethers.utils.toUtf8Bytes(data);
  
  // Compute the keccak256 hash
  const blobHash = ethers.utils.keccak256(dataBytes);
  
  console.log("Blob Hash:", blobHash);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 