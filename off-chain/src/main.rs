/// @author Parsa Aminpour
/// @notice this script generate a merkle tree from eligible addresses registered in eligible_addresses.txt file.
/// @note you should change addresses inside eligible_addresses.txt if you want to call whitelist function in ZeroDay smart contract.
use sha3::{Keccak256, Digest};
use serde::{Serialize, Deserialize};
use serde_json;
use std::fs::File;
use std::io::{self, BufRead};
use std::path::Path;
use inline_colorization::*;

#[derive(Debug, Serialize, Deserialize, Clone)]
struct MerkleNode {
    hash: String,
    left: Option<Box<MerkleNode>>,
    right: Option<Box<MerkleNode>>,
}

impl MerkleNode {
    fn new(hash: String) -> Self {
        MerkleNode {
            hash,
            left: None,
            right: None,
        }
    }
}

fn hash_pair(left: &str, right: &str) -> String {
    let mut hasher = Keccak256::new();
    hasher.update(left.as_bytes());
    hasher.update(right.as_bytes());
    format!("{:x}", hasher.finalize())
}

fn build_merkle_tree(mut leaves: Vec<MerkleNode>) -> MerkleNode {
    while leaves.len() > 1 {
        let mut next_level = Vec::new();
        for i in (0..leaves.len()).step_by(2) {
            if i + 1 < leaves.len() {
                let left = leaves[i].clone();
                let right = leaves[i + 1].clone();
                let parent_hash = hash_pair(&left.hash, &right.hash);
                let mut parent = MerkleNode::new(parent_hash);
                parent.left = Some(Box::new(left));
                parent.right = Some(Box::new(right));
                next_level.push(parent);
            } else {
                next_level.push(leaves[i].clone());
            }
        }
        leaves = next_level;
    }
    leaves.remove(0)
}

fn read_addresses_from_file(filename: &str) -> io::Result<Vec<String>> {
    let path = Path::new(filename);
    let file = File::open(&path)?;
    let lines = io::BufReader::new(file).lines();
    
    let mut addresses = Vec::new();
    for line in lines {
        if let Ok(address) = line {
            addresses.push(address);
        }
    }
    Ok(addresses)
}

fn get_merkle_proof(node: &MerkleNode, target_hash: &str) -> Vec<String> {
    let mut proof = Vec::new();
    build_proof(node, target_hash, &mut proof);
    proof
}

fn build_proof(node: &MerkleNode, target_hash: &str, proof: &mut Vec<String>) -> bool {
    if node.hash == target_hash {
        return true;
    }
    if let Some(ref left) = node.left {
        if build_proof(left, target_hash, proof) {
            if let Some(ref right) = node.right {
                proof.push(right.hash.clone());
            }
            return true;
        }
    }
    if let Some(ref right) = node.right {
        if build_proof(right, target_hash, proof) {
            if let Some(ref left) = node.left {
                proof.push(left.hash.clone());
            }
            return true;
        }
    }
    false
}

fn main() -> io::Result<()> {
    let addresses = read_addresses_from_file("eligible_addresses.txt")?;
    
    let leaves: Vec<MerkleNode> = addresses.iter()
        .map(|addr| {
            let mut hasher = Keccak256::new();
            hasher.update(addr.as_bytes());
            let hash = format!("{:x}", hasher.finalize());
            MerkleNode::new(hash)
        })
        .collect();

    let merkle_root = build_merkle_tree(leaves.clone());
    let serialized_tree = serde_json::to_string_pretty(&merkle_root).unwrap();

    println!("Merkle Tree: {}", serialized_tree);
    
    // Generate Merkle proof for a specific address
    // @note change this target_address, output is directly depends on this variable.
    let target_address = "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"; // replace with the address you want to generate proof for
    let mut hasher = Keccak256::new();
    hasher.update(target_address.as_bytes());
    let target_hash = format!("{:x}", hasher.finalize());
    let proof = get_merkle_proof(&merkle_root, &target_hash);
    
    println!("Merkle Root: {color_green}{}{color_reset}", merkle_root.hash);
    println!("Merkle Proof for {color_blue}{}{color_reset}: {:?}", target_address, proof);

    Ok(())
}