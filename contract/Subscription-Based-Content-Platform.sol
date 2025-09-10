// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Subscription-Based Content Platform
 * @dev A decentralized platform for content creators to monetize through subscriptions
 * @author Smart Contract Developer
 */
contract Project {
    
    // State variables
    address public owner;
    uint256 public nextContentId = 1;
    uint256 public nextSubscriptionId = 1;
    
    // Structs
    struct Content {
        uint256 id;
        address creator;
        string title;
        string description;
        uint256 subscriptionPrice; // Price in wei for monthly subscription
        uint256 totalSubscribers;
        bool isActive;
        uint256 createdAt;
    }
    
    struct Subscription {
        uint256 id;
        address subscriber;
        uint256 contentId;
        uint256 expiresAt;
        bool isActive;
        uint256 subscribedAt;
    }
    
    // Mappings
    mapping(uint256 => Content) public contents;
    mapping(uint256 => Subscription) public subscriptions;
    mapping(address => uint256[]) public userSubscriptions;
    mapping(address => uint256[]) public creatorContents;
    mapping(uint256 => uint256[]) public contentSubscriptions;
    
    // Events
    event ContentCreated(
        uint256 indexed contentId,
        address indexed creator,
        string title,
        uint256 subscriptionPrice
    );
    
    event SubscriptionPurchased(
        uint256 indexed subscriptionId,
        address indexed subscriber,
        uint256 indexed contentId,
        uint256 expiresAt
    );
    
    event ContentUpdated(
        uint256 indexed contentId,
        string newTitle,
        string newDescription,
        uint256 newPrice
    );
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier contentExists(uint256 _contentId) {
        require(contents[_contentId].id != 0, "Content does not exist");
        _;
    }
    
    modifier onlyCreator(uint256 _contentId) {
        require(contents[_contentId].creator == msg.sender, "Only content creator can call this");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Core Function 1: Create Content
     * @param _title Title of the content
     * @param _description Description of the content
     * @param _subscriptionPrice Monthly subscription price in wei
     */
    function createContent(
        string memory _title,
        string memory _description,
        uint256 _subscriptionPrice
    ) external {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(_subscriptionPrice > 0, "Subscription price must be greater than 0");
        
        Content memory newContent = Content({
            id: nextContentId,
            creator: msg.sender,
            title: _title,
            description: _description,
            subscriptionPrice: _subscriptionPrice,
            totalSubscribers: 0,
            isActive: true,
            createdAt: block.timestamp
        });
        
        contents[nextContentId] = newContent;
        creatorContents[msg.sender].push(nextContentId);
        
        emit ContentCreated(nextContentId, msg.sender, _title, _subscriptionPrice);
        nextContentId++;
    }
    
    /**
     * @dev Core Function 2: Subscribe to Content
     * @param _contentId ID of the content to subscribe to
     */
    function subscribeToContent(uint256 _contentId) external payable contentExists(_contentId) {
        Content storage content = contents[_contentId];
        require(content.isActive, "Content is not active");
        require(msg.value >= content.subscriptionPrice, "Insufficient payment");
        require(msg.sender != content.creator, "Creators cannot subscribe to their own content");
        
        // Check if user already has an active subscription
        require(!hasActiveSubscription(msg.sender, _contentId), "Already subscribed to this content");
        
        // Calculate subscription expiry (30 days from now)
        uint256 expiryTime = block.timestamp + 30 days;
        
        Subscription memory newSubscription = Subscription({
            id: nextSubscriptionId,
            subscriber: msg.sender,
            contentId: _contentId,
            expiresAt: expiryTime,
            isActive: true,
            subscribedAt: block.timestamp
        });
        
        subscriptions[nextSubscriptionId] = newSubscription;
        userSubscriptions[msg.sender].push(nextSubscriptionId);
        contentSubscriptions[_contentId].push(nextSubscriptionId);
        
        // Update content statistics
        content.totalSubscribers++;
        
        // Transfer payment to content creator (platform could take a fee here)
        payable(content.creator).transfer(msg.value);
        
        emit SubscriptionPurchased(nextSubscriptionId, msg.sender, _contentId, expiryTime);
        nextSubscriptionId++;
    }
    
    /**
     * @dev Core Function 3: Update Content
     * @param _contentId ID of the content to update
     * @param _newTitle New title for the content
     * @param _newDescription New description for the content
     * @param _newPrice New subscription price
     */
    function updateContent(
        uint256 _contentId,
        string memory _newTitle,
        string memory _newDescription,
        uint256 _newPrice
    ) external contentExists(_contentId) onlyCreator(_contentId) {
        require(bytes(_newTitle).length > 0, "Title cannot be empty");
        require(_newPrice > 0, "Price must be greater than 0");
        
        Content storage content = contents[_contentId];
        content.title = _newTitle;
        content.description = _newDescription;
        content.subscriptionPrice = _newPrice;
        
        emit ContentUpdated(_contentId, _newTitle, _newDescription, _newPrice);
    }
    
    // Helper Functions
    
    /**
     * @dev Check if a user has an active subscription to specific content
     * @param _user Address of the user
     * @param _contentId ID of the content
     * @return bool True if user has active subscription
     */
    function hasActiveSubscription(address _user, uint256 _contentId) public view returns (bool) {
        uint256[] memory userSubs = userSubscriptions[_user];
        
        for (uint256 i = 0; i < userSubs.length; i++) {
            Subscription memory sub = subscriptions[userSubs[i]];
            if (sub.contentId == _contentId && sub.isActive && sub.expiresAt > block.timestamp) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * @dev Get all content IDs created by a specific creator
     * @param _creator Address of the creator
     * @return uint256[] Array of content IDs
     */
    function getCreatorContents(address _creator) external view returns (uint256[] memory) {
        return creatorContents[_creator];
    }
    
    /**
     * @dev Get all subscription IDs for a specific user
     * @param _user Address of the user
     * @return uint256[] Array of subscription IDs
     */
    function getUserSubscriptions(address _user) external view returns (uint256[] memory) {
        return userSubscriptions[_user];
    }
    
    /**
     * @dev Toggle content active status
     * @param _contentId ID of the content
     */
    function toggleContentStatus(uint256 _contentId) external contentExists(_contentId) onlyCreator(_contentId) {
        contents[_contentId].isActive = !contents[_contentId].isActive;
    }
    
    /**
     * @dev Get total number of active contents
     * @return uint256 Total active contents
     */
    function getTotalActiveContents() external view returns (uint256) {
        uint256 activeCount = 0;
        for (uint256 i = 1; i < nextContentId; i++) {
            if (contents[i].isActive) {
                activeCount++;
            }
        }
        return activeCount;
    }
}
