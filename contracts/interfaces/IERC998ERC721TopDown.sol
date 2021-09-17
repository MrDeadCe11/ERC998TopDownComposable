// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

/// @title ERC998ERC721 Top-Down Composable Non-Fungible Token
/// @dev See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-998.md
///  Note: the ERC-165 identifier for this interface is 0x1efdf36a
interface IERC998ERC721TopDown {

    /// @dev This emits when a token receives a child token.
    /// @param _from The prior owner of the token.
    /// @param _toTokenId The token that receives the child token.
    event ReceivedChild(
        address indexed _from,
        uint256 indexed _toTokenId,
        address indexed _childContract,
        uint256 _childTokenId
    );

    /// @dev This emits when a child token is transferred from a token to an address.
    /// @param _fromTokenId The parent token that the child token is being transferred from.
    /// @param _to The new owner address of the child token.
    event TransferChild(
        uint256 indexed _fromTokenId,
        address indexed _to,
        address indexed _childContract,
        uint256 _childTokenId
    );

    /// @notice Get the root owner of tokenId.
    /// @param _tokenId The token to query for a root owner address
    /// @return rootOwner The root owner at the top of tree of tokens and ERC998 magic value.
    /// swithed from pubic to external
    function rootOwnerOf(
        uint256 _tokenId
    ) external view returns (
        bytes32 rootOwner
    );

    /// @notice Get the root owner of a child token.
    /// @param _childContract The contract address of the child token.
    /// @param _childTokenId The tokenId of the child.
    /// @return rootOwner The root owner at the top of tree of tokens and ERC998 magic value.
    /// swithed from pubic to external
    function rootOwnerOfChild(
        address _childContract,
        uint256 _childTokenId
    ) external view returns (
        bytes32 rootOwner
    );

    /// @notice Get the parent tokenId of a child token.
    /// @param _childContract The contract address of the child token.
    /// @param _childTokenId The tokenId of the child.
    /// @return parentTokenOwner The parent address of the parent token and ERC998 magic value
    /// @return parentTokenId The parent tokenId of _tokenId
    function ownerOfChild(
        address _childContract,
        uint256 _childTokenId
    ) external view returns (
        bytes32 parentTokenOwner,
        uint256 parentTokenId
    );

    /// @notice A token receives a child token
    /// @param _operator The address that caused the transfer.
    /// @param _from The owner of the child token.
    /// @param _childTokenId The token that is being transferred to the parent.
    /// @param _data Up to the first 32 bytes contains an integer which is the receiving parent tokenId.
    function onERC721Received(
        address _operator,
        address _from,
        uint256 _childTokenId,
        bytes calldata _data
    ) external returns(bytes4);

    /// @notice Transfer child token from top-down composable to address.
    /// @param _fromTokenId The owning token to transfer from.
    /// @param _to The address that receives the child token
    /// @param _childContract The ERC721 contract of the child token.
    /// @param _childTokenId The tokenId of the token that is being transferred.
    function transferChild(
        uint256 _fromTokenId,
        address _to,
        address _childContract,
        uint256 _childTokenId
    ) external;

    /// @notice Transfer child token from top-down composable to address.
    /// @param _fromTokenId The owning token to transfer from.
    /// @param _to The address that receives the child token
    /// @param _childContract The ERC721 contract of the child token.
    /// @param _childTokenId The tokenId of the token that is being transferred.
    function safeTransferChild(
        uint256 _fromTokenId,
        address _to,
        address _childContract,
        uint256 _childTokenId
    ) external;

    /// @notice Transfer child token from top-down composable to address.
    /// @param _fromTokenId The owning token to transfer from.
    /// @param _to The address that receives the child token
    /// @param _childContract The ERC721 contract of the child token.
    /// @param _childTokenId The tokenId of the token that is being transferred.
    /// @param _data Additional data with no specified format
    function safeTransferChild(
        uint256 _fromTokenId,
        address _to,
        address _childContract,
        uint256 _childTokenId,
        bytes calldata _data
    ) external;

    /// @notice Transfer bottom-up composable child token from top-down composable to other ERC721 token.
    /// @param _fromTokenId The owning token to transfer from.
    /// @param _toContract The ERC721 contract of the receiving token
    /// @param _toTokenId The receiving token
    /// @param _childContract The bottom-up composable contract of the child token.
    /// @param _childTokenId The token that is being transferred.
    /// @param _data Additional data with no specified format
    function transferChildToParent(
        uint256 _fromTokenId,
        address _toContract,
        uint256 _toTokenId,
        address _childContract,
        uint256 _childTokenId,
        bytes calldata _data
    ) external;

    /// @notice Get a child token from an ERC721 contract.
    /// @param _from The address that owns the child token.
    /// @param _tokenId The token that becomes the parent owner
    /// @param _childContract The ERC721 contract of the child token
    /// @param _childTokenId The tokenId of the child token
    function getChild(
        address _from,
        uint256 _tokenId,
        address _childContract,
        uint256 _childTokenId
    ) external;
}
