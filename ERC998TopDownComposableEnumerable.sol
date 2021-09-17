// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "hardhat/console.sol";
import "./interfaces/IERC998ERC721TopDown.sol";
import "./interfaces/ERC998ERC721TopDownEnumerable.sol";
import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

interface IERC998ERC721BottomUp {
  function transferToParent(
    address _from,
    address _toContract,
    uint256 _toTokenId,
    uint256 _tokenId,
    bytes calldata _data
  ) external;
}

contract ERC998 is
  IERC998ERC721TopDown,
  ERC165,
  ERC998ERC721TopDownEnumerable,
  ERC721,
  ERC721Enumerable,
  ERC721URIStorage,
  Pausable,
  Ownable,
  ERC721Burnable
{
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIdCounter;

  constructor() ERC721("ERC998", "TOP") {}

  // tokenId => token owner
  mapping(uint256 => address) internal tokenIdToTokenOwner;

  // root token owner address => (tokenId => approved address)
  mapping(address => mapping(uint256 => address))
    internal rootOwnerAndTokenIdToApprovedAddress;

  // token owner => (operator address => bool)
  mapping(address => mapping(address => bool)) internal tokenOwnerToOperators;

  // tokenId => child contract
  mapping(uint256 => address[]) private childContracts;

  // tokenId => (child address => contract index+1)
  mapping(uint256 => mapping(address => uint256)) private childContractIndex;

  // tokenId => (child address => array of child tokens)
  mapping(uint256 => mapping(address => uint256[])) private childTokens;

  // tokenId => (child address => (child token => child index+1)
  mapping(uint256 => mapping(address => mapping(uint256 => uint256)))
    private childTokenIndex;

  // token owner address => token count
  mapping(address => uint256) internal tokenOwnerToTokenCount;

  // child address => childId => tokenId
  mapping(address => mapping(uint256 => uint256)) internal childTokenOwner;

  // return this.rootOwnerOf.selector ^ this.rootOwnerOfChild.selector ^
  //   this.tokenOwnerOf.selector ^ this.ownerOfChild.selector;
  bytes32 public constant ERC998_MAGIC_VALUE =
    0x00000000000000000000000000000000000000000000000000000000cd740db5;

  //from zepellin ERC721Receiver.sol
  //old version
  bytes4 public constant ERC721_RECEIVED_OLD = 0xf0b9e5ba;
  //new version
  bytes4 public constant ERC721_RECEIVED_NEW = 0x150b7a02;

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  event parentNftMinted(uint256 indexed tokenId, address indexed to);
  event childNftMinted(uint256 indexed tokenId, address indexed to);

  function mintParent(address _to, string calldata _ipfsUri)
    public
    returns (uint256)
  {
    uint256 tokenId = _tokenIdCounter.current();
    //mint token
    _safeMint(_to, tokenId);
    _setTokenURI(tokenId, _ipfsUri);
    //update parent mappings
    tokenIdToTokenOwner[tokenId] = _to;

    tokenOwnerToTokenCount[_to]++;
    //increment counter
    _tokenIdCounter.increment();
    emit parentNftMinted(tokenId, address(_to));

    return tokenId;
  }

  //mintChild is still a work in progress don't use yet.
  function mintChild(uint256 _parentId, string calldata _ipfsUri)
    public
    returns (uint256)
  {
    uint256 tokenId = _tokenIdCounter.current();
    address rootOwner = tokenIdToTokenOwner[_parentId];
    console.log("tokenId", tokenId, "Root Owner", rootOwner);
    //mint token
    _safeMint(rootOwner, tokenId);
    _setTokenURI(tokenId, _ipfsUri);

    //update mappings
    childContracts[_parentId].push(address(this));

    tokenIdToTokenOwner[tokenId] = rootOwner;

    childContractIndex[tokenId][address(this)]++;

    childTokenIndex[_parentId][address(this)][tokenId]++;

    childTokenOwner[address(this)][tokenId] = _parentId;

    childTokens[_parentId][address(this)].push(tokenId);

    tokenOwnerToTokenCount[rootOwner]++;

    _tokenIdCounter.increment();
    emit childNftMinted(tokenId, address(rootOwner));

    return tokenId;
  }

  function convertBytes32ToAddress(bytes32 root) public pure returns (address) {
    return address(uint160(uint256(root)));
  }

  function convertAddressToUint(address a) internal pure returns (uint256) {
    return uint256(uint160(a));
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  // The following functions are overrides required by Solidity.

  function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
    super._burn(tokenId);
  }

  // function addToPortfolio() {
  //     uint256 tokenId = 6;
  //     bytes memory tokenIdBytes = new bytes(32);
  //     assembly { mstore(add(tokenIdBytes, 32), tokenId) }
  //     safeTransferFrom(msg.sender, address(), 3, tokenIdBytes);
  // }

  function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721, ERC721URIStorage)
    returns (string memory)
  {
    return super.tokenURI(tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable, ERC165)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function isContract(address _addr) internal view returns (bool) {
    uint256 size;
    assembly {
      size := extcodesize(_addr)
    }
    return size > 0;
  }

  // returns the owner at the top of the tree of composables

  function slice(
    bytes memory _bytes,
    uint256 _start,
    uint256 _length
  ) internal pure returns (bytes memory) {
    require(_length + 31 >= _length, "slice_overflow");
    require(_start + _length >= _start, "slice_overflow");
    require(_bytes.length >= _start + _length, "slice_outOfBounds");

    bytes memory tempBytes;

    assembly {
      switch iszero(_length)
      case 0 {
        // Get a location of some free memory and store it in tempBytes as
        // Solidity does for memory variables.
        tempBytes := mload(0x40)

        // The first word of the slice result is potentially a partial
        // word read from the original array. To read it, we calculate
        // the length of that partial word and start copying that many
        // bytes into the array. The first word we copy will start with
        // data we don't care about, but the last `lengthmod` bytes will
        // land at the beginning of the contents of the new array. When
        // we're done copying, we overwrite the full first word with
        // the actual length of the slice.
        let lengthmod := and(_length, 31)

        // The multiplication in the next line is necessary
        // because when slicing multiples of 32 bytes (lengthmod == 0)
        // the following copy loop was copying the origin's length
        // and then ending prematurely not copying everything it should.
        let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
        let end := add(mc, _length)

        for {
          // The multiplication in the next line has the same exact purpose
          // as the one above.
          let cc := add(
            add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))),
            _start
          )
        } lt(mc, end) {
          mc := add(mc, 0x20)
          cc := add(cc, 0x20)
        } {
          mstore(mc, mload(cc))
        }

        mstore(tempBytes, _length)

        //update free-memory pointer
        //allocating the array padded to 32 bytes like the compiler does now
        mstore(0x40, and(add(mc, 31), not(31)))
      }
      //if we want a zero-length slice let's just return a zero-length array
      default {
        tempBytes := mload(0x40)
        //zero out the 32 bytes slice we are about to return
        //we need to do it because Solidity does not garbage collect
        mstore(tempBytes, 0)

        mstore(0x40, add(tempBytes, 0x20))
      }
    }

    return tempBytes;
  }

  function toAddress(bytes32 _bytes, uint256 _start)
    internal
    pure
    returns (address)
  {
    require(_start + 20 >= _start, "toAddress_overflow");
    require(_bytes.length >= _start + 20, "toAddress_outOfBounds");
    address tempAddress;

    assembly {
      tempAddress := div(
        mload(add(add(_bytes, 0x20), _start)),
        0x1000000000000000000000000
      )
    }
    return tempAddress;
  }

  function toUint24(bytes memory _bytes, uint256 _start)
    internal
    pure
    returns (uint24)
  {
    require(_start + 3 >= _start, "toUint24_overflow");
    require(_bytes.length >= _start + 3, "toUint24_outOfBounds");
    uint24 tempUint;

    assembly {
      tempUint := mload(add(add(_bytes, 0x3), _start))
    }

    return tempUint;
  }

  ////////////////////////////////////////////////////////
  // ERC721 implementation
  ////////////////////////////////////////////////////////

  function rootOwnerOf(uint256 _tokenId)
    public
    view
    override
    returns (bytes32 rootOwner)
  {
    return rootOwnerOfChild(address(0), _tokenId);
  }

  function addressOfRootOwner(address _childContract, uint256 _childTokenId)
    public
    view
    returns (address)
  {
    bytes32 data = rootOwnerOfChild(_childContract, _childTokenId);
    return convertBytes32ToAddress(data);
  }

  // returns the owner at the top of the tree of composables
  // Use Cases handled:
  // Case 1: Token owner is this contract and token.
  // Case 2: Token owner is other top-down composable
  // Case 3: Token owner is other contract
  // Case 4: Token owner is user
  function rootOwnerOfChild(address _childContract, uint256 _childTokenId)
    public
    view
    override
    returns (bytes32 rootOwner)
  {
    address rootOwnerAddress;
    if (_childContract != address(0)) {
      (rootOwnerAddress, _childTokenId) = _ownerOfChild(
        _childContract,
        _childTokenId
      );
    } else {
      rootOwnerAddress = tokenIdToTokenOwner[_childTokenId];
    }
    // Case 1: Token owner is this contract and token.
    while (rootOwnerAddress == address(this)) {
      (rootOwnerAddress, _childTokenId) = _ownerOfChild(
        rootOwnerAddress,
        _childTokenId
      );
    }

    (bool callSuccess, bytes memory data) = rootOwnerAddress.staticcall(
      abi.encodeWithSelector(0xed81cdda, address(this), _childTokenId)
    );
    if (data.length != 0) {
      rootOwner = abi.decode(data, (bytes32));
    }

    if (callSuccess == true && rootOwner >> 224 == ERC998_MAGIC_VALUE) {
      // Case 2: Token owner is other top-down composable
      return rootOwner;
    } else {
      // Case 3: Token owner is other contract
      // Or
      // Case 4: Token owner is user
      uint256 rootOwnerInt = convertAddressToUint(rootOwnerAddress);
      return (ERC998_MAGIC_VALUE << 224) | bytes32(rootOwnerInt);
    }
  }

  function ownerOf(uint256 _tokenId)
    public
    view
    override
    returns (address tokenOwner)
  {
    tokenOwner = tokenIdToTokenOwner[_tokenId];
    require(tokenOwner != address(0), "token owned by zero address");
    return tokenOwner;
  }

  function balanceOf(address _tokenOwner)
    public
    view
    override
    returns (uint256)
  {
    require(_tokenOwner != address(0), "not owned");
    return tokenOwnerToTokenCount[_tokenOwner];
  }

  function approve(address _approved, uint256 _tokenId) public override {
    address rootOwner = address(uint160(uint256(rootOwnerOf(_tokenId))));
    require(
      rootOwner == msg.sender || tokenOwnerToOperators[rootOwner][msg.sender],
      "You cannot approve this."
    );
    rootOwnerAndTokenIdToApprovedAddress[rootOwner][_tokenId] = _approved;
    emit Approval(rootOwner, _approved, _tokenId);
  }

  function getApproved(uint256 _tokenId)
    public
    view
    override
    returns (address)
  {
    address rootOwner = address(uint160(uint256(rootOwnerOf(_tokenId))));
    return rootOwnerAndTokenIdToApprovedAddress[rootOwner][_tokenId];
  }

  function setApprovalForAll(address _operator, bool _approved)
    public
    override
  {
    require(_operator != address(0), "token not owned");
    tokenOwnerToOperators[msg.sender][_operator] = _approved;
    emit ApprovalForAll(msg.sender, _operator, _approved);
  }

  function isApprovedForAll(address _owner, address _operator)
    public
    view
    override
    returns (bool)
  {
    require(_owner != address(0), "token not owned");
    require(_operator != address(0), "no operator");
    return tokenOwnerToOperators[_owner][_operator];
  }

  //_from is the current owner address, _to will be the tokenId of the token you want to tranfer ownership to OR the wallet to tranfer to, _tokenId is the token you will be transfering
  function _transferFrom(
    address _from,
    address _to,
    uint256 _tokenId
  ) private {
    require(_from != address(0), "also not");
    require(
      tokenIdToTokenOwner[_tokenId] == _from,
      "token cannot be owned by sender"
    );
    require(_to != address(0), "not from dead address");

    if (msg.sender != _from) {
      (bool callSuccess, bytes memory data) = _from.staticcall(
        abi.encodeWithSelector(0xed81cdda, address(this), _tokenId)
      );
      bytes32 rootOwner = abi.decode(data, (bytes32));

      if (callSuccess == true) {
        require(
          rootOwner >> 224 != ERC998_MAGIC_VALUE,
          "This child already has a parent."
        );
      }
      require(
        tokenOwnerToOperators[_from][msg.sender] ||
          rootOwnerAndTokenIdToApprovedAddress[_from][_tokenId] == msg.sender,
        "You are not approved."
      );
    }

    // clear approval
    if (rootOwnerAndTokenIdToApprovedAddress[_from][_tokenId] != address(0)) {
      delete rootOwnerAndTokenIdToApprovedAddress[_from][_tokenId];
      emit Approval(_from, address(0), _tokenId);
    }

    // remove and transfer token
    if (_from != _to) {
      assert(tokenOwnerToTokenCount[_from] > 0);
      tokenOwnerToTokenCount[_from]--;
      tokenIdToTokenOwner[_tokenId] = _to;
      tokenOwnerToTokenCount[_to]++;
    }
    emit Transfer(_from, _to, _tokenId);
  }

  function transferFrom(
    address _from,
    address _to,
    uint256 _tokenId
  ) public override {
    _transferFrom(_from, _to, _tokenId);
  }

  function safeTransferFrom(
    address _from,
    address _to,
    uint256 _tokenId
  ) public override {
    _transferFrom(_from, _to, _tokenId);
    if (isContract(_to)) {
      bytes4 retval = IERC721Receiver(_to).onERC721Received(
        msg.sender,
        _from,
        _tokenId,
        ""
      );
      require(retval == ERC721_RECEIVED_OLD, "retval invalid");
    }
  }

  //_from = address that owns parent nft, _to = address that minted the child nft, _tokenId = childNft ID, _data = parent NFT ID
  function safeTransferFrom(
    address _from,
    address _to,
    uint256 _tokenId,
    bytes calldata _data
  ) public override {
    _transferFrom(_from, _to, _tokenId);
    if (isContract(_to)) {
      bytes4 retval = IERC721Receiver(_to).onERC721Received(
        msg.sender,
        _from,
        _tokenId,
        _data
      );
      require(
        retval == ERC721_RECEIVED_OLD || retval == ERC721_RECEIVED_NEW,
        "incorrect retval"
      );
    }
  }

  ////////////////////////////////////////////////////////
  // ERC998ERC721 and ERC998ERC721Enumerable implementation
  ////////////////////////////////////////////////////////

  // tokenId of composable, mapped to child contract address
  // child contract address mapped to child tokenId or amount
  mapping(uint256 => mapping(address => uint256)) children;

  // add ERC-721 children by tokenId
  // @requires owner to approve transfer from this contract
  // call _childContract.approve(this, _childTokenId)
  // where this is the address of the parent token contract
  /////////////////////WIP////////////////////////////////
  // function addChild(
  //   uint256 _tokenId,
  //   address _childContract,
  //   uint256 _childTokenId
  // ) public returns (bytes32) {
  //   // call the transfer function of the child contract
  //   // if approve was called using the address of this contract
  //   // _childTokenId will be transferred to this contract
  //   (bool callSuccess, bytes memory data) = _childContract.staticcall(
  //     abi.encode(
  //       bytes4(keccak256("transferFrom(address,address,uint256)")),
  //       msg.sender,
  //       this,
  //       _childTokenId
  //     )
  //   );
  //   require(callSuccess, "call failed");
  //   // if successful, add children to the mapping
  //   children[_tokenId][_childContract] = _childTokenId;
  //   //transfer token
  // }
////////////////////////////WIP///////////////////////////
  function removeChild(
    uint256 _tokenId,
    address _childContract,
    uint256 _childTokenId
  ) private {
    uint256 tokenIndex = childTokenIndex[_tokenId][_childContract][
      _childTokenId
    ];
    require(tokenIndex != 0, "this token is not a child token.");

    // remove child token
    uint256 lastTokenIndex = childTokens[_tokenId][_childContract].length - 1;
    uint256 lastToken = childTokens[_tokenId][_childContract][lastTokenIndex];
    if (_childTokenId == lastToken) {
      childTokens[_tokenId][_childContract][tokenIndex - 1] = lastToken;
      childTokenIndex[_tokenId][_childContract][lastToken] = tokenIndex;
    }
    uint256 totalTokens = childTokens[_tokenId][_childContract].length;
    if (totalTokens - 1 == 0) {
      delete childTokens[_tokenId][_childContract];
    } else {
      delete childTokens[_tokenId][_childContract][totalTokens - 1];
    }
    delete childTokenIndex[_tokenId][_childContract][_childTokenId];
    delete childTokenOwner[_childContract][_childTokenId];

    // remove contract
    if (lastTokenIndex == 0) {
      uint256 lastContractIndex = childContracts[_tokenId].length - 1;
      address lastContract = childContracts[_tokenId][lastContractIndex];
      if (_childContract != lastContract) {
        uint256 contractIndex = childContractIndex[_tokenId][_childContract];
        childContracts[_tokenId][contractIndex] = lastContract;
        childContractIndex[_tokenId][lastContract] = contractIndex;
      }
      delete childContracts[_tokenId];
      delete childContractIndex[_tokenId][_childContract];
    }
  }

  function safeTransferChild(
    uint256 _fromTokenId,
    address _to,
    address _childContract,
    uint256 _childTokenId
  ) external override {
    uint256 tokenId = childTokenOwner[_childContract][_childTokenId];
    require(
      tokenId > 0 ||
        childTokenIndex[tokenId][_childContract][_childTokenId] > 0,
      "not a child token"
    );
    require(tokenId == _fromTokenId, "cannot send to same token");
    require(_to != address(0), "token owned by zero address");
    address rootOwner = address(uint160(uint256(rootOwnerOf(tokenId))));
    require(
      rootOwner == msg.sender ||
        tokenOwnerToOperators[rootOwner][msg.sender] ||
        rootOwnerAndTokenIdToApprovedAddress[rootOwner][tokenId] == msg.sender,
      "you are not approved."
    );
    removeChild(tokenId, _childContract, _childTokenId);
    IERC721(_childContract).safeTransferFrom(address(this), _to, _childTokenId);
    emit TransferChild(tokenId, _to, _childContract, _childTokenId);
  }

  function safeTransferChild(
    uint256 _fromTokenId,
    address _to,
    address _childContract,
    uint256 _childTokenId,
    bytes calldata _data
  ) external override {
    uint256 tokenId = childTokenOwner[_childContract][_childTokenId];
    require(
      tokenId > 0 ||
        childTokenIndex[tokenId][_childContract][_childTokenId] > 0,
      "not a child token"
    );
    require(tokenId == _fromTokenId);
    require(_to != address(0));
    address rootOwner = address(uint160(uint256(rootOwnerOf(tokenId))));
    require(
      rootOwner == msg.sender ||
        tokenOwnerToOperators[rootOwner][msg.sender] ||
        rootOwnerAndTokenIdToApprovedAddress[rootOwner][tokenId] == msg.sender,
      "you are not approved."
    );
    removeChild(tokenId, _childContract, _childTokenId);
    IERC721(_childContract).safeTransferFrom(
      address(this),
      _to,
      _childTokenId,
      _data
    );
    emit TransferChild(tokenId, _to, _childContract, _childTokenId);
  }

  function transferChild(
    uint256 _fromTokenId,
    address _to,
    address _childContract,
    uint256 _childTokenId
  ) external override {
    uint256 tokenId = childTokenOwner[_childContract][_childTokenId];
    require(
      tokenId > 0 ||
        childTokenIndex[tokenId][_childContract][_childTokenId] > 0,
      "can only transfer child tokens"
    );
    require(tokenId == _fromTokenId, "cannot send same token");
    require(_to != address(0), "don't burn this.");
    address rootOwner = address(uint160(uint256(rootOwnerOf(tokenId))));
    require(
      rootOwner == msg.sender ||
        tokenOwnerToOperators[rootOwner][msg.sender] ||
        rootOwnerAndTokenIdToApprovedAddress[rootOwner][tokenId] == msg.sender,
      "you are not approved"
    );
    removeChild(tokenId, _childContract, _childTokenId);
    //this is here to be compatible with cryptokitties and other old contracts that require being owner and approved
    // before transferring.
    //does not work with current standard which does not allow approving self, so we must let it fail in that case.
    //0x095ea7b3 == "approve(address,uint256)"

    (bool success, bytes memory data) = _childContract.call(
      abi.encodeWithSelector(0x095ea7b3, this, _childTokenId)
    );
    require(
      success && (data.length == 0 || abi.decode(data, (bool))),
      "failed to approve"
    );

    IERC721(_childContract).transferFrom(address(this), _to, _childTokenId);
    emit TransferChild(tokenId, _to, _childContract, _childTokenId);
  }

  function transferChildToParent(
    uint256 _fromTokenId,
    address _toContract,
    uint256 _toTokenId,
    address _childContract,
    uint256 _childTokenId,
    bytes calldata _data
  ) external override {
    uint256 tokenId = childTokenOwner[_childContract][_childTokenId];
    require(
      tokenId > 0 ||
        childTokenIndex[tokenId][_childContract][_childTokenId] > 0,
      "not a child token"
    );
    require(tokenId == _fromTokenId, "token can't send itself");
    require(_toContract != address(0), "don't burn this");
    address rootOwner = address(uint160(uint256(rootOwnerOf(tokenId))));
    require(
      rootOwner == msg.sender ||
        tokenOwnerToOperators[rootOwner][msg.sender] ||
        rootOwnerAndTokenIdToApprovedAddress[rootOwner][tokenId] == msg.sender,
      "you are not approved"
    );
    removeChild(_fromTokenId, _childContract, _childTokenId);
    IERC998ERC721BottomUp(_childContract).transferToParent(
      address(this),
      _toContract,
      _toTokenId,
      _childTokenId,
      _data
    );
    emit TransferChild(
      _fromTokenId,
      _toContract,
      _childContract,
      _childTokenId
    );
  }

  // this contract has to be approved first in _childContract
  function getChild(
    address _from,
    uint256 _tokenId,
    address _childContract,
    uint256 _childTokenId
  ) external override {
    receiveChild(_from, _tokenId, _childContract, _childTokenId);
    require(
      _from == msg.sender ||
        IERC721(_childContract).isApprovedForAll(_from, msg.sender) ||
        IERC721(_childContract).getApproved(_childTokenId) == msg.sender,
      "you are not approved"
    );
    IERC721(_childContract).transferFrom(_from, address(this), _childTokenId);
  }

  function onERC721Received(
    address _from,
    uint256 _childTokenId,
    bytes calldata _data
  ) external returns (bytes4) {
    require(_data.length > 0, "no token id.");
    // convert up to 32 bytes of_data to uint256, owner nft tokenId passed as uint in bytes
    uint256 tokenId;
    assembly {
      tokenId := calldataload(132)
    }
    if (_data.length < 32) {
      tokenId = tokenId >> (256 - _data.length * 8);
    }
    receiveChild(_from, tokenId, msg.sender, _childTokenId);
    require(
      IERC721(msg.sender).ownerOf(_childTokenId) != address(0),
      "Child token not owned."
    );
    return ERC721_RECEIVED_OLD;
  }

  function onERC721Received(
    address _operator,
    address _from,
    uint256 _childTokenId,
    bytes calldata _data
  ) external override returns (bytes4) {
    require(_data.length > 0, "parent not found");
    // convert up to 32 bytes of_data to uint256, owner nft tokenId passed as uint in bytes
    uint256 tokenId;
    assembly {
      tokenId := calldataload(164)
    }
    if (_data.length < 32) {
      tokenId = tokenId >> (256 - _data.length * 8);
    }
    receiveChild(_from, tokenId, msg.sender, _childTokenId);
    require(
      IERC721(msg.sender).ownerOf(_childTokenId) != address(0),
      "Child token not owned."
    );
    return ERC721_RECEIVED_NEW;
  }

  function receiveChild(
    address _from,
    uint256 _tokenId,
    address _childContract,
    uint256 _childTokenId
  ) private {
    require(
      tokenIdToTokenOwner[_tokenId] != address(0),
      "_tokenId does not exist."
    );
    require(
      childTokenIndex[_tokenId][_childContract][_childTokenId] == 0,
      "no child token sent."
    );
    uint256 childTokensLength = childTokens[_tokenId][_childContract].length;
    if (childTokensLength == 0) {
      childContractIndex[_tokenId][_childContract] = childContracts[_tokenId]
        .length;
      childContracts[_tokenId].push(_childContract);
    }
    childTokens[_tokenId][_childContract].push(_childTokenId);
    childTokenIndex[_tokenId][_childContract][_childTokenId] =
      childTokensLength +
      1;
    childTokenOwner[_childContract][_childTokenId] = _tokenId;
    emit ReceivedChild(_from, _tokenId, _childContract, _childTokenId);
  }

  function _ownerOfChild(address _childContract, uint256 _childTokenId)
    internal
    view
    returns (address parentTokenOwner, uint256 parentTokenId)
  {
    parentTokenId = childTokenOwner[_childContract][_childTokenId];
    require(
      parentTokenId > 0 ||
        childTokenIndex[parentTokenId][_childContract][_childTokenId] > 0,
      "not a child"
    );
    return (tokenIdToTokenOwner[parentTokenId], parentTokenId);
  }

  function ownerOfChild(address _childContract, uint256 _childTokenId)
    external
    view
    override
    returns (bytes32 parentTokenOwner, uint256 parentTokenId)
  {
    parentTokenId = childTokenOwner[_childContract][_childTokenId];
    require(
      parentTokenId > 0 ||
        childTokenIndex[parentTokenId][_childContract][_childTokenId] > 0,
      "not a child"
    );
    uint256 tokenIdOwnerInt = convertAddressToUint(
      tokenIdToTokenOwner[parentTokenId]
    );
    return (
      (ERC998_MAGIC_VALUE << 224) | bytes32(tokenIdOwnerInt),
      parentTokenId
    );
  }

  function childExists(address _childContract, uint256 _childTokenId)
    external
    view
    returns (bool)
  {
    uint256 tokenId = childTokenOwner[_childContract][_childTokenId];
    return childTokenIndex[tokenId][_childContract][_childTokenId] != 0;
  }

  function totalChildContracts(uint256 _tokenId)
    external
    view
    override
    returns (uint256)
  {
    return childContracts[_tokenId].length;
  }

  function childContractByIndex(uint256 _tokenId, uint256 _index)
    external
    view
    override
    returns (address childContract)
  {
    require(_index < childContracts[_tokenId].length, "wrong index");
    return childContracts[_tokenId][_index];
  }

  function totalChildTokens(uint256 _tokenId, address _childContract)
    external
    view
    override
    returns (uint256)
  {
    return childTokens[_tokenId][_childContract].length;
  }

  function childTokenByIndex(
    uint256 _tokenId,
    address _childContract,
    uint256 _index
  ) external view override returns (uint256 childTokenId) {
    require(
      _index < childTokens[_tokenId][_childContract].length,
      "wrong index."
    );
    return childTokens[_tokenId][_childContract][_index];
  }
}
