//sandbox
//["0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"]
// testnet MetaMask
//contract v1 at testnet - 0xA817F715FaA3E7ee19FB41A2aA6585b06897cb51
//v1.1 - 0xDb1fa87118627E1850B9144EEFd43B46b35F3eD9
//v1.2 - 0xb2F7e75926cacfD83Ee7B5c4cb04F573Ee58eC76
//v1.3 - 0x3899c379c4deef307ceb1c3f3265be3c9a6ff5cf
//v1.31 - 0x095c9236725235a4CD94C609fc259D886001188E
//v1.32 - 0x25681E3817EEfb9bBFdBC4398A30AfFfA407aA52
//v1.33 - 0x004177bF37568A178BD510DB6644a3645a97e749
//v1.4 - 0x0CaE274079600c2175B5dC322c2F7FCdb5985A62 - for github page
//v1.41 - 0x65FE4d1dc8e9F11edDd92D8e13d4884CDaA1a8B9 - optimize all users
//v1.42 - 0x85Ec8e4dC2548f6FCCdc18A09aF37078ce69a465 - optimize comparison with 1.41 split to 3 users instead of all users
//v1.43 - 0x08321c0FEa5Ca2B59dA91983d81b0B36230a5507 - optimize 200 compile
//v1.44 - 0xeF2F67Cac4f6fd4B1E653aC4C02D5bF7653E1C7C - test single transfer with multitransfer
//v1.45 - 0x930e1664789031048666D190E8008FE0a729188f - optimize functions
//0x73e612F58362f44Bb0Af24fA074B147b30389252   - owner at testnet
//["0x3EbD46521802ab19A2411De9fe34C9cb7E6B3FA7","0xa010d14032A7e24f9374182E5663E743Dc66321F"]
pragma solidity >=0.4.23 <0.6.0;

contract SingleNeko{

    struct User{
        uint id;
        uint itemCount;
        address referrer;
        mapping(uint => Item)items;
        mapping(uint => uint)userItemsIdbyItemId;
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

    uint256[] private winnerArr = new uint256[](8);
    uint8 public lastItemId = 0;
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
    function getWinners() public view returns(address[] memory,uint[] memory){
        address[] memory winnerAddress = new address[](8);
        uint[] memory winnerAmount = new uint[](8);

        for(uint256 i=0;i<winnerArr.length;i++){
            winnerAddress[i] = ownerOf(winnerArr[i]);
            winnerAmount[i] = users[ownerOf(winnerArr[i])].items[winnerArr[i]].LastWinAmount;
        }
        return(winnerAddress,winnerAmount);
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

        users[userAddress].items[lastItemId] = item;
        users[userAddress].userItemsIdbyItemId[lastItemId] = users[userAddress].itemCount;
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
            resultID[i] = users[user].items[users[user].userItemsIdbyItemId[i]].id;
            resultPower[i] = users[user].items[users[user].userItemsIdbyItemId[i]].power;
            resultLastWin[i] = users[user].items[users[user].userItemsIdbyItemId[i]].LastWinAmount;
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

        users[userAddress].items[lastItemId] = item;
        users[userAddress].userItemsIdbyItemId[lastItemId] = users[userAddress].itemCount;
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
        if(totalItem > 0 && totalItem % 4 == 0){
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
        delete winnerArr;
        winnerArr = new uint256[](8);
        if(lastItemId > 0){
            if(lastItemId > totalReward){
                for (uint256 i = 0; i < 8; i++) {
                    uint256 n = i + uint256(keccak256(abi.encodePacked(block.timestamp))) % (lastItemId - i);
                    winnerArr[i]=n;
                }
            }else{
                for (uint256 i = 0; i < 8; i++) {
                    winnerArr[i]=i;
                }
                totalReward = lastItemId;
            }

            uint totalPower = 0;
            for(uint i=0;i<totalReward;i++){
                totalPower += users[ownerOf(winnerArr[i])].items[winnerArr[i]].power;
            }
            for(uint i=0;i<totalReward;i++){
                uint reward = itemRewardPrice*users[ownerOf(winnerArr[i])].items[winnerArr[i]].power/totalPower;
                giveETH(ownerOf(winnerArr[i]),reward);
                users[ownerOf(winnerArr[i])].items[winnerArr[i]].LastWinAmount = reward;
                emit SentExtraEthDividends(user, ownerOf(users[ownerOf(winnerArr[i])].items[winnerArr[i]].id));
            }
        }
    }
    function singleTransfer(address receiver) external payable{
        giveETH(receiver,msg.value);
        uint256 itemPower = generateRandomNum(receiver,10,8);
        Item memory item = Item({
            id:lastItemId,
            power:itemPower,
            LastWinAmount:0,
            owner:receiver
        });
        users[receiver].items[users[receiver].itemCount] = item;
    }
    function x8Transfer(address receiver) external payable{
        uint reward = msg.value/12;
        for(uint i=0;i<8;i++){
            giveETH(receiver,reward);
        }
        uint256 itemPower = generateRandomNum(msg.sender,10,8);
        Item memory item = Item({
            id:lastItemId,
            power:itemPower,
            LastWinAmount:0,
            owner:msg.sender
        });
        users[msg.sender].items[users[msg.sender].itemCount] = item;
        users[msg.sender].itemCount++;
        lastItemId++;
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

    /**
     * @dev Returns the owner of the NFT specified by `tokenId`.
     */
    function ownerOf(uint256 tokenId) public view returns (address _owner){
        address itemOwner = userAddressByItemId[tokenId];
        require(itemOwner != address(0), "Invalid Item ID.");
        return itemOwner;
    }

}
