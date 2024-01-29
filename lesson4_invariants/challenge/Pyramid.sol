pragma solidity ^0.8.0;

/**
 * @title Pyramid - a pyramid scheme
 * @author Certora
 * @notice address(0) cannot be a member
 *
 * @dev The pyramid is a binary tree, with a unique root. The members of the pyramid
 * scheme are the nodes of this tree. So each member may have a parent and up to two
 * children. The contract also keeps track of the balance of each member in the scheme.
 *
 * @notice A memeber can join another to the scheme as its child. There is a fixed 
 * joining price for joining the scheme, paid by the parent from their balance in the
 * scheme.
 *
 * When a child withdraws funds from the scheme, a part of their balance in the scheme
 * is trransferred to their parent.
 *
 * Challenge rules
 * ---------------
 * 1. The goal is to create a spec that will capture the most mutations. We will include
 *    some manual malicious mutations.
 * 2. The methods `withdraw` and `deposit` will not be mutated.
 * 3. The winner or winners will be the specs that caught the most mutations.
 * 4. Use only invariants, ghosts and hooks. Rules will not be accepted.
 * 5. Harnessing is not allowed.
 */
contract Pyramid {

  /**
   * @notice Member data
   * @param balance - The member's balance in the scheme
   * @param exists - True only if member has joined the scheme
   */
  struct Member {
    uint256 balance;
    bool exists;
    address parent;
    address leftChild;
    address rightChild;
  }

  mapping(address => Member) private members;  // All pyramid members
  address private _root; // The root of the binary tree

  uint256 public immutable parentFrac;
  uint256 public immutable joiningFee;

  constructor(
    uint256 _parentFrac,
    uint256 _joiningFee
  ) {
    require(_parentFrac > 0, "Must be non-zero");
    parentFrac = _parentFrac;
    joiningFee = _joiningFee;
    
    // Set the root
    require(msg.sender != address(0), "Address zero cannot be a member");
    _root = msg.sender;
    Member storage memberData = members[msg.sender];
    memberData.exists = true;
  }

  /**
   * @dev Restricts access to scheme members only
   */
  modifier memebersOnly() {
    require(contains(msg.sender), "Not a member");
    _;
  }

  /**
   * @return If the given address is a member
   */
  function contains(address member) public view returns (bool) {
    return members[member].exists;
  }

  /**
   * @return the unique root of the binary tree
   */
  function root() public view returns (address) {
    return _root;
  }

  /**
   * @return The member's balance in the pyramid scheme
   */
  function balanceOf(address member) memebersOnly() public view returns (uint256) {
    Member storage memberData = members[member];
    return memberData.balance;
  }

  /**
   * @notice Method for depositing into the pyramid scheme by the sender. Converts
   * deposited amount to balance in the scheme.
   */
  function deposit() memebersOnly() external payable {
    Member storage memberData = members[msg.sender];
    memberData.balance += msg.value;
  }

  /**
   * @return The child's parent
   */
  function getParent(address child) memebersOnly() public view returns (address) {
    require(contains(child), "Not a member");
    return members[child].parent;
  }

  /**
   * @param isRight - Use true for referring to the right child, use false for the left
   * @return The right or left child
   */
  function getChild(
    address parent,
    bool isRight
  ) memebersOnly() public view returns (address) {
    require(contains(parent), "Not a member");
    Member storage memberData = members[parent];
    if (isRight) {
      return memberData.rightChild;
    } else {
      return memberData.leftChild;
    }
  }

  /**
   * @param isRight - Use true for referring to the right child, use false for the left
   * @return If the relevant child of the parent address exists
   */
  function hasChild(
    address parent,
    bool isRight
  ) memebersOnly() public view returns (bool) {
    return getChild(parent, isRight) != address(0);
  }

  /**
   * @notice Method for withdrawing from the pyramid scheme for the sender
   * @dev For every amount x withdrawn, an amount x/y of the sender's balance will be
   * given to the sender's parent, where y is `parentFrac` (the root is excluded from
   * this).
   */
  function withdraw(uint256 amount) memebersOnly() public {
    Member storage memberData = members[msg.sender];

    // If there is no parent than the parent part is zero
    uint256 parentPart = contains(memberData.parent) ? amount / parentFrac : 0;
    uint256 totalRemove = amount + parentPart;
    require(memberData.balance >= totalRemove, "Insufficient funds");

    memberData.balance -= totalRemove;
    
    // Send parent part
    members[memberData.parent].balance += parentPart;
    
    // Send member's payment
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success);
  }

  /**
   * @notice Method for the sender to join a new member as a child
   * @param child - The address of the member to join
   * @param isRight - Use true to add the member as the right child, use false to add
   * them as the left child
   * @dev A joining fee amount will be deducted from the sender's balance in the scheme
   */
  function join(address child, bool isRight) memebersOnly() public {
    require(!hasChild(msg.sender, isRight), "Child already exists");
    require(!contains(child), "Child already a member");
    require(child != address(0), "Address zero cannot be a member");

    // Deduct joining fee
    Member storage memberData = members[msg.sender];
    require(memberData.balance >= joiningFee, "Insufficient funds");
    memberData.balance -= joiningFee;

    // Create child
    members[child].exists = true;
    members[child].parent = msg.sender;

    // Add child
    if (isRight) {
      memberData.rightChild = child;
    } else {
      memberData.leftChild = child;
    }
  }
}