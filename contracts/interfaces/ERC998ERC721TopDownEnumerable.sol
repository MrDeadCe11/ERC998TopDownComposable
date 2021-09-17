// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

///  @dev The ERC-165 identifier for this interface is 0xa344afe4
interface ERC998ERC721TopDownEnumerable {

  /// @notice Get the total number of child contracts with tokens that are owned by tokenId.
  /// @param _tokenId The parent token of child tokens in child contracts
  /// @return uint256 The total number of child contracts with tokens owned by tokenId.
  function totalChildContracts(uint256 _tokenId) external view returns(uint256);
  
  /// @notice Get child contract by tokenId and index
  /// @param _tokenId The parent token of child tokens in child contract
  /// @param _index The index position of the child contract
  /// @return childContract The contract found at the tokenId and index.
  function childContractByIndex(
    uint256 _tokenId, 
    uint256 _index
  ) 
    external 
    view 
    returns (address childContract);
  
  /// @notice Get the total number of child tokens owned by tokenId that exist in a child contract.
  /// @param _tokenId The parent token of child tokens
  /// @param _childContract The child contract containing the child tokens
  /// @return uint256 The total number of child tokens found in child contract that are owned by tokenId.
  function totalChildTokens(
    uint256 _tokenId, 
    address _childContract
  ) 
    external 
    view 
    returns(uint256);
  
  /// @notice Get child token owned by tokenId, in child contract, at index position
  /// @param _tokenId The parent token of the child token
  /// @param _childContract The child contract of the child token
  /// @param _index The index position of the child token.
  /// @return childTokenId The child tokenId for the parent token, child token and index
  function childTokenByIndex(
    uint256 _tokenId, 
    address _childContract, 
    uint256 _index
  )
    external 
    view 
    returns (uint256 childTokenId);
}