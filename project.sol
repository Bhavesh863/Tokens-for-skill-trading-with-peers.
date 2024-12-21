// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SkillTradingToken is ERC20, Ownable, ReentrancyGuard {
    struct Skill {
        string name;
        string description;
        uint256 ratePerHour;
        bool isActive;
    }

    struct Trade {
        address provider;
        address receiver;
        uint256 skillId;
        uint256 duration;
        uint256 totalAmount;
        bool isCompleted;
        bool isDisputed;
    }

    mapping(uint256 => Skill) public skills;
    mapping(address => mapping(uint256 => bool)) public userSkills;
    mapping(uint256 => Trade) public trades;
    
    uint256 public skillCount;
    uint256 public tradeCount;
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18; // 1 million tokens
    
    event SkillRegistered(uint256 indexed skillId, string name, address indexed provider);
    event TradeInitiated(uint256 indexed tradeId, address indexed provider, address indexed receiver);
    event TradeCompleted(uint256 indexed tradeId);
    event TradeDisputed(uint256 indexed tradeId);

    constructor() ERC20("SkillTrade", "SKILL") Ownable(msg.sender) ReentrancyGuard() {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function registerSkill(string memory _name, string memory _description, uint256 _ratePerHour) 
        external 
        returns (uint256)
    {
        require(bytes(_name).length > 0, "Skill name cannot be empty");
        require(_ratePerHour > 0, "Rate must be greater than 0");

        skillCount++;
        skills[skillCount] = Skill({
            name: _name,
            description: _description,
            ratePerHour: _ratePerHour,
            isActive: true
        });

        userSkills[msg.sender][skillCount] = true;
        
        emit SkillRegistered(skillCount, _name, msg.sender);
        return skillCount;
    }

    function initiateTrade(uint256 _skillId, address _provider, uint256 _duration) 
        external 
        nonReentrant 
        returns (uint256)
    {
        require(userSkills[_provider][_skillId], "Provider does not have this skill");
        require(_duration > 0, "Duration must be greater than 0");
        require(_provider != msg.sender, "Cannot trade with yourself");

        Skill memory skill = skills[_skillId];
        uint256 totalAmount = skill.ratePerHour * _duration;
        
        require(balanceOf(msg.sender) >= totalAmount, "Insufficient balance");
        
        tradeCount++;
        trades[tradeCount] = Trade({
            provider: _provider,
            receiver: msg.sender,
            skillId: _skillId,
            duration: _duration,
            totalAmount: totalAmount,
            isCompleted: false,
            isDisputed: false
        });

        _transfer(msg.sender, address(this), totalAmount);
        
        emit TradeInitiated(tradeCount, _provider, msg.sender);
        return tradeCount;
    }

    function completeTrade(uint256 _tradeId) external nonReentrant {
        Trade storage trade = trades[_tradeId];
        require(!trade.isCompleted, "Trade already completed");
        require(!trade.isDisputed, "Trade is disputed");
        require(msg.sender == trade.receiver, "Only receiver can complete trade");

        trade.isCompleted = true;
        _transfer(address(this), trade.provider, trade.totalAmount);
        
        emit TradeCompleted(_tradeId);
    }

    function disputeTrade(uint256 _tradeId) external {
        Trade storage trade = trades[_tradeId];
        require(!trade.isCompleted, "Trade already completed");
        require(msg.sender == trade.provider || msg.sender == trade.receiver, "Not involved in trade");
        
        trade.isDisputed = true;
        emit TradeDisputed(_tradeId);
    }

    function deactivateSkill(uint256 _skillId) external {
        require(userSkills[msg.sender][_skillId], "Not your skill");
        skills[_skillId].isActive = false;
    }

    function getSkill(uint256 _skillId) external view returns (Skill memory) {
        return skills[_skillId];
    }

    function getTrade(uint256 _tradeId) external view returns (Trade memory) {
        return trades[_tradeId];
    }
}