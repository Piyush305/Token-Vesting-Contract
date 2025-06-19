
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Project - Token Vesting Contract
 * @dev Simple token vesting contract with three core functions
 */
contract Project {
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        uint256 releasedAmount;
        bool isActive;
    }
    
    address public owner;
    address public tokenAddress;
    
    mapping(address => VestingSchedule) public vestingSchedules;
    address[] public beneficiaries;
    
    uint256 public totalVestingAmount;
    uint256 public totalReleasedAmount;
    
    event VestingCreated(address indexed beneficiary, uint256 amount);
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    constructor(address _tokenAddress) {
        owner = msg.sender;
        tokenAddress = _tokenAddress;
    }
    
    /**
     * @dev Core Function 1: Create a vesting schedule for a beneficiary
     * @param beneficiary The address that will receive vested tokens
     * @param totalAmount Total amount of tokens to vest
     * @param cliffDurationInDays Cliff period in days
     * @param vestingDurationInDays Total vesting period in days
     */
    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 cliffDurationInDays,
        uint256 vestingDurationInDays
    ) external onlyOwner {
        require(beneficiary != address(0), "Invalid beneficiary address");
        require(totalAmount > 0, "Amount must be greater than 0");
        require(vestingDurationInDays > 0, "Vesting duration must be greater than 0");
        require(cliffDurationInDays <= vestingDurationInDays, "Cliff cannot be longer than vesting");
        require(!vestingSchedules[beneficiary].isActive, "Vesting schedule already exists");
        
        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: totalAmount,
            startTime: block.timestamp,
            cliffDuration: cliffDurationInDays * 1 days,
            vestingDuration: vestingDurationInDays * 1 days,
            releasedAmount: 0,
            isActive: true
        });
        
        beneficiaries.push(beneficiary);
        totalVestingAmount += totalAmount;
        
        emit VestingCreated(beneficiary, totalAmount);
    }
    
    /**
     * @dev Core Function 2: Release vested tokens to beneficiary
     * @param beneficiary The address to release tokens for
     */
    function releaseVestedTokens(address beneficiary) external {
        require(
            msg.sender == beneficiary || msg.sender == owner,
            "Only beneficiary or owner can release tokens"
        );
        
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.isActive, "No active vesting schedule");
        
        uint256 vestedAmount = calculateVestedAmount(beneficiary);
        uint256 releasableAmount = vestedAmount - schedule.releasedAmount;
        
        require(releasableAmount > 0, "No tokens available for release");
        
        schedule.releasedAmount += releasableAmount;
        totalReleasedAmount += releasableAmount;
        
        // Simple token transfer (assumes contract has the tokens)
        // In real deployment, you would integrate with actual ERC20 token
        
        emit TokensReleased(beneficiary, releasableAmount);
    }
    
    /**
     * @dev Core Function 3: Revoke a vesting schedule
     * @param beneficiary The address whose vesting to revoke
     */
    function revokeVesting(address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.isActive, "Vesting schedule not active");
        
        // Calculate any tokens that should be released before revoking
        uint256 vestedAmount = calculateVestedAmount(beneficiary);
        uint256 releasableAmount = vestedAmount - schedule.releasedAmount;
        
        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            totalReleasedAmount += releasableAmount;
            emit TokensReleased(beneficiary, releasableAmount);
        }
        
        schedule.isActive = false;
        emit VestingRevoked(beneficiary);
    }
    
    /**
     * @dev Calculate the amount of tokens that have vested for a beneficiary
     * @param beneficiary The address to calculate vested amount for
     * @return The amount of tokens vested
     */
    function calculateVestedAmount(address beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
        
        if (!schedule.isActive) {
            return 0;
        }
        
        uint256 currentTime = block.timestamp;
        
        // If we're before the cliff, no tokens are vested
        if (currentTime < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }
        
        // If we're past the vesting period, all tokens are vested
        if (currentTime >= schedule.startTime + schedule.vestingDuration) {
            return schedule.totalAmount;
        }
        
        // Linear vesting between cliff and end
        uint256 timeFromStart = currentTime - schedule.startTime;
        return (schedule.totalAmount * timeFromStart) / schedule.vestingDuration;
    }
    
    /**
     * @dev Get vesting schedule details for a beneficiary
     * @param beneficiary The address to get details for
     * @return totalAmount Total tokens in the schedule
     * @return startTime When vesting started
     * @return cliffDuration Cliff period in seconds
     * @return vestingDuration Total vesting period in seconds
     * @return releasedAmount Tokens already released
     * @return isActive Whether the schedule is active
     */
    function getVestingSchedule(address beneficiary) external view returns (
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 releasedAmount,
        bool isActive
    ) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
        return (
            schedule.totalAmount,
            schedule.startTime,
            schedule.cliffDuration,
            schedule.vestingDuration,
            schedule.releasedAmount,
            schedule.isActive
        );
    }
    
    /**
     * @dev Get the amount of tokens available for release
     * @param beneficiary The address to check
     * @return Amount of tokens ready to be released
     */
    function getReleasableAmount(address beneficiary) external view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
        if (!schedule.isActive) {
            return 0;
        }
        
        uint256 vested = calculateVestedAmount(beneficiary);
        return vested - schedule.releasedAmount;
    }
    
    /**
     * @dev Get contract statistics
     * @return totalBeneficiaries Number of beneficiaries
     * @return totalVesting Total amount being vested
     * @return totalReleased Total amount already released
     */
    function getContractStats() external view returns (
        uint256 totalBeneficiaries,
        uint256 totalVesting,
        uint256 totalReleased
    ) {
        return (beneficiaries.length, totalVestingAmount, totalReleasedAmount);
    }
    
    /**
     * @dev Get all beneficiaries
     * @return Array of all beneficiary addresses
     */
    function getAllBeneficiaries() external view returns (address[] memory) {
        return beneficiaries;
    }
    
    /**
     * @dev Change contract owner
     * @param newOwner Address of the new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
    
    /**
     * @dev Update token address (in case of token migration)
     * @param newTokenAddress Address of the new token contract
     */
    function updateTokenAddress(address newTokenAddress) external onlyOwner {
        require(newTokenAddress != address(0), "Token address cannot be zero");
        tokenAddress = newTokenAddress;
    }
}
