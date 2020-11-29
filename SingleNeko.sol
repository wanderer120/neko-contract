//sandbox
//["0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"]
// testnet MetaMask
//contract v1 at testnet - 0xA817F715FaA3E7ee19FB41A2aA6585b06897cb51
//v1.1 - 0xDb1fa87118627E1850B9144EEFd43B46b35F3eD9
//v1.2 - 0xb2F7e75926cacfD83Ee7B5c4cb04F573Ee58eC76
//v1.3 - 0x3899c379c4deef307ceb1c3f3265be3c9a6ff5cf
//v1.31 - 0x095c9236725235a4CD94C609fc259D886001188E
//v1.32 - 0x25681E3817EEfb9bBFdBC4398A30AfFfA407aA52
//0x73e612F58362f44Bb0Af24fA074B147b30389252   - owner at testnet
//["0x3EbD46521802ab19A2411De9fe34C9cb7E6B3FA7","0xa010d14032A7e24f9374182E5663E743Dc66321F"]
pragma solidity >=0.4.23 <0.6.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/docs-v2.x/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/docs-v2.x/contracts/token/ERC721/IERC721Receiver.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/docs-v2.x/contracts/introspection/ERC165.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/docs-v2.x/contracts/math/SafeMath.sol";

contract SingleNeko is IERC721, ERC165 {

    struct User{
        uint id;
        uint itemCount;
        address referrer;
        mapping(uint => Item)items;
    }
    struct Item{
        uint id;
        uint power;
        uint LastWinAmount;
        address owner;
    }

    event Registration(address indexed user, address indexed referrer, uint indexed userId, uint referrerId);
    event SentExtraEthDividends(address indexed from, address indexed receiver);
    //inherited events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event BuyItemEvent(address indexed user, uint itemId);

    address public owner;
    mapping(uint => address) public technicianAddress;
    uint totalTechnician;

    mapping(address => User) public users;
    uint8 public lastUserId = 2;//1 is owner
    mapping(uint => address) public idToAddress;

    uint8 public lastItemId = 0;
    Item[] public allItems;
    mapping(uint => address) public userAddressByItemId;

    uint public itemPrice = 0.05 ether;
    uint public itemRewardPrice;
    uint public backCommission;
    uint public uplineCommision;

    constructor(address ownerAddress, address[] memory techAddress) public {
        owner = ownerAddress;
        totalTechnician = techAddress.length;
        for(uint8 i = 0; i < techAddress.length;i++){
            technicianAddress[i] = techAddress[i];
        }
        User memory user = User({
            id: 1,
            referrer: address(0),
            itemCount: 0
        });

        users[ownerAddress] = user;
        idToAddress[1] = ownerAddress;
        uplineCommision = itemPrice / 5;// 1 upline or super upline 20%
        backCommission = itemPrice / 10; // 2 tech + 1 owner 10% each
        itemRewardPrice = (itemPrice - (backCommission * (totalTechnician + 1 )) - uplineCommision);// remainder
    }
    function buyItemExt() external payable {
        buyItem(msg.sender);
    }
    function buyItem(address userAddress) private {
        require(msg.value == 0.05 ether, "registration cost 0.05 ether");
        require(isUserExists(userAddress), "user not exists");
        uint32 size;
        assembly {
            size := extcodesize(userAddress)
        }
        require(size == 0, "cannot be a contract");

        splitRewards(userAddress,users[userAddress].referrer);

        //create item
        uint256 itemPower = generateRandomNum(userAddress,10,8);
        Item memory item = Item({
            id:lastItemId,
            power:itemPower,
            LastWinAmount:0,
            owner:userAddress
        });

        users[userAddress].items[users[userAddress].itemCount] = item;
        allItems.push(item);
        userAddressByItemId[lastItemId] = userAddress;

        users[userAddress].itemCount++;
        lastItemId++;
        emit BuyItemEvent(userAddress, (lastItemId-1));
    }
    function getAllItemsByUser(address user)public view returns (uint[] memory, uint[] memory, uint[] memory){
        uint[] memory resultID = new uint256[](users[user].itemCount);
        uint[] memory resultPower = new uint256[](users[user].itemCount);
        uint[] memory resultLastWin = new uint256[](users[user].itemCount);
        for(uint i=0;i<users[user].itemCount;i++){
            resultID[i] = users[user].items[i].id;
            resultPower[i] = users[user].items[i].power;
            resultLastWin[i] = users[user].items[i].LastWinAmount;
        }
        return (resultID, resultPower, resultLastWin);
    }
    function registrationExt(address referrerAddress) external payable {
        registration(msg.sender, referrerAddress);
    }
    function registration(address userAddress, address referrerAddress) private {

        require(msg.value == 0.05 ether, "registration cost 0.05 ether");
        require(!isUserExists(userAddress), "user exists");
        require(isUserExists(referrerAddress), "referrer not exists");
        uint32 size;
        assembly {
            size := extcodesize(userAddress)
        }
        require(size == 0, "cannot be a contract");

        //split rewards
        splitRewards(userAddress,referrerAddress);

        //Create user
        User memory user = User({
            id: lastUserId,
            referrer: referrerAddress,
            itemCount: 0
        });
        users[userAddress] = user;
        idToAddress[lastUserId] = userAddress;
        users[userAddress].referrer = referrerAddress;
        lastUserId++;

        //create item
        uint256 itemPower = generateRandomNum(userAddress,10,8);
        Item memory item = Item({
            id:lastItemId,
            power:itemPower,
            LastWinAmount:0,
            owner:userAddress
        });

        users[userAddress].items[users[userAddress].itemCount] = item;
        allItems.push(item);
        userAddressByItemId[lastItemId] = userAddress;

        users[userAddress].itemCount++;
        lastItemId++;

        emit Registration(userAddress, referrerAddress, users[userAddress].id, users[referrerAddress].id);

    }
    function splitRewards(address user, address referrerAddress) private {
        //Give commission to owner
        giveETH(owner,backCommission);
        emit SentExtraEthDividends(user, owner);

        //Give commission to technicians
        for(uint8 i =0;i<totalTechnician;i++){
            giveETH(technicianAddress[i],backCommission);
            emit SentExtraEthDividends(user, technicianAddress[i]);
        }

        //give rewards to upline
        uint totalItem = users[referrerAddress].itemCount;
        if(totalItem % 4 == 0){
            //Last slot goes to super upline
            if(referrerAddress!=owner){
              giveETH(users[referrerAddress].referrer,uplineCommision);
              emit SentExtraEthDividends(user, users[referrerAddress].referrer);
            }else{
              giveETH(owner,uplineCommision);
              emit SentExtraEthDividends(user, owner);
            }


        }else{
            //goes to upline
            giveETH(referrerAddress,uplineCommision);
            emit SentExtraEthDividends(user, referrerAddress);
        }

        //Give rewards to random 8 users
        uint totalReward = 8;
        if(allItems.length > 0){
            if(allItems.length > totalReward){

                for (uint256 i = 0; i < 8; i++) {
                    uint256 n = i + uint256(keccak256(abi.encodePacked(block.timestamp))) % (allItems.length - i);
                    Item memory temp = allItems[n];
                    allItems[n] = allItems[i];
                    allItems[i] = temp;
                }
            }else{
                totalReward = allItems.length;
            }
            uint totalPower = 0;
            for(uint i=0;i<totalReward;i++){
                totalPower += allItems[i].power;
            }
            for(uint i=0;i<totalReward;i++){
                uint reward = itemRewardPrice*allItems[i].power/totalPower;
                giveETH(ownerOf(allItems[i].id),reward);
                allItems[i].LastWinAmount = reward;
                emit SentExtraEthDividends(user, ownerOf(allItems[i].id));
            }
        }
    }
    function giveETH(address receiver, uint amount) private{
        if (!address(uint160(receiver)).send(amount)) {
            return address(uint160(receiver)).transfer(address(this).balance);
        }
    }
    function isUserExists(address user) public view returns (bool) {
        return (users[user].id != 0);
    }
    function generateRandomNum(address _owner, uint modulo, uint256 digits) public view
        returns (uint256)
    {
        // Generates random uint from string (name) + address (owner)
        uint256 rand = uint256(keccak256(abi.encodePacked(block.timestamp))) +
            uint256(_owner);
        rand = rand % (modulo ** digits);
        return rand;
    }
    //inherited functions
    /**
     * @dev Returns the number of NFTs in ``owner``'s account.
     */
    function balanceOf(address _owner) public view returns (uint256 balance){
        return users[_owner].itemCount;
    }

    /**
     * @dev Returns the owner of the NFT specified by `tokenId`.
     */
    function ownerOf(uint256 tokenId) public view returns (address _owner){
        address itemOwner = userAddressByItemId[tokenId];
        require(itemOwner != address(0), "Invalid Item ID.");
        return itemOwner;
    }

    /**
     * @dev Transfers a specific NFT (`tokenId`) from one account (`from`) to
     * another (`to`).
     *
     *
     *
     * Requirements:
     * - `from`, `to` cannot be zero.
     * - `tokenId` must be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this
     * NFT by either {approve} or {setApprovalForAll}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public{

    }
    /**
     * @dev Transfers a specific NFT (`tokenId`) from one account (`from`) to
     * another (`to`).
     *
     * Requirements:
     * - If the caller is not `from`, it must be approved to move this NFT by
     * either {approve} or {setApprovalForAll}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public{

    }
    function approve(address to, uint256 tokenId) public{

    }
    function getApproved(uint256 tokenId) public view returns (address operator){

    }

    function setApprovalForAll(address operator, bool _approved) public{

    }
    function isApprovedForAll(address _owner, address operator) public view returns (bool){

    }


    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public{

    }
}
