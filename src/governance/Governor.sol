// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {HarborDAO} from "./HarborDAO.sol";
import {PoolManager} from "../pool/poolManager.sol";

contract Governor {
    error Already_FM();
    error Not_FM();
    error Forbidden_Tier();
    error Invalid_Value();

    event NewFMProposed(address indexed proposer, address indexed proposedFM);
    event FMRemovalProposed(
        address indexed proposer,
        address indexed fundManager
    );
    event TierChangeProposed(
        address indexed proposer,
        address indexed fundManager,
        uint256 indexed newTier
    );
    event RewardChangeProposed(
        address indexed proposer,
        uint256 indexed newRewardPercentage
    );
    event AllowanceChangeProposed(
        address indexed proposer,
        uint256 indexed tier,
        uint256 indexed newAllowance
    );

    enum Type {
        ADD_FM,
        REMOVE_FM,
        CHANGE_TIER,
        CHANGE_REWARD,
        CHANGE_ALLOWANCE
    }

    mapping(uint256 proposalId => address proposedFMAddr)
        private s_proposalIdToFMAddr;
    mapping(uint256 proposalId => uint256 tier) private s_proposalIdToTier;
    mapping(uint256 proposalId => uint256 newAllowance)
        private s_proposalIdToAllowance;
    mapping(uint256 proposalId => uint256 newRewardPercentage)
        private s_proposalIdToRewardPercentage;
    mapping(uint256 proposalId => Type) private s_proposalTypes;

    HarborDAO private immutable i_dao;
    PoolManager private immutable i_poolManager;
    uint256 private immutable i_poolId;

    constructor(uint256 poolId, address daoAddr, address poolManager) {
        i_dao = HarborDAO(daoAddr);
        i_poolId = poolId;
        i_poolManager = PoolManager(poolManager);
    }

    /**
     * @dev Proposes a new fund manager to be added to the pool
     */

    function proposeNewFM(address newFM) public returns (uint256) {
        if (i_poolManager.isManager(newFM)) revert Already_FM();

        uint256 proposalId = i_dao.createNewProposal(msg.sender, i_poolId);
        s_proposalIdToFMAddr[proposalId] = newFM;
        s_proposalTypes[proposalId] = Type.ADD_FM;

        emit NewFMProposed(msg.sender, newFM);
        return proposalId;
    }

    /**
     * @dev Proposes a fund manager to be removed from the pool
     */

    function proposeRemoveFM(address fundManager) public returns (uint256) {
        if (!i_poolManager.isManager(fundManager)) revert Not_FM();

        uint256 proposalId = i_dao.createNewProposal(msg.sender, i_poolId);
        s_proposalIdToFMAddr[proposalId] = fundManager;
        s_proposalTypes[proposalId] = Type.REMOVE_FM;

        emit FMRemovalProposed(msg.sender, fundManager);
        return proposalId;
    }

    /**
     * @dev Proposes a change in tier for a fund manager
     */

    function proposeChangeTier(
        address fundManager,
        uint256 tier
    ) public returns (uint256) {
        if (!i_poolManager.isManager(fundManager)) revert Not_FM();
        if (tier < 1 || tier > 3) revert Forbidden_Tier();
        if (tier == uint256(i_poolManager.getTier(fundManager)) + 1)
            revert Forbidden_Tier();

        uint256 proposalId = i_dao.createNewProposal(msg.sender, i_poolId);
        s_proposalIdToTier[proposalId] = tier;
        s_proposalIdToFMAddr[proposalId] = fundManager;
        s_proposalTypes[proposalId] = Type.CHANGE_TIER;

        emit TierChangeProposed(msg.sender, fundManager, tier);
        return proposalId;
    }

    /**
     * @dev Proposes a change in the allowance for a tier
     */

    function proposeChangeAllowance(
        uint256 _tier,
        uint256 newAllowance
    ) public returns (uint256) {
        if (_tier < 1 || _tier > 3) revert Forbidden_Tier();
        PoolManager.Tier tier = PoolManager.Tier(_tier - 1);

        if (
            newAllowance > i_poolManager.getMaxAllownace(tier) ||
            newAllowance < i_poolManager.getMinAllownace(tier)
        ) revert Invalid_Value();

        uint256 proposalId = i_dao.createNewProposal(msg.sender, i_poolId);
        s_proposalIdToAllowance[proposalId] = newAllowance;
        s_proposalIdToTier[proposalId] = _tier;
        s_proposalTypes[proposalId] = Type.CHANGE_ALLOWANCE;

        emit AllowanceChangeProposed(msg.sender, _tier, newAllowance);
        return proposalId;
    }

    /**
     * @dev Proposes a change in the reward percentage for the fund managers
     */

    function proposeChangeReward(
        uint256 newRewardPercentage
    ) public returns (uint256) {
        if (
            newRewardPercentage > i_poolManager.MAX_REWARD_PERCENTAGE() ||
            newRewardPercentage < i_poolManager.MIN_REWARD_PERCENTAGE()
        ) revert Invalid_Value();

        uint256 proposalId = i_dao.createNewProposal(msg.sender, i_poolId);
        s_proposalIdToRewardPercentage[proposalId] = newRewardPercentage;
        s_proposalTypes[proposalId] = Type.CHANGE_REWARD;

        emit RewardChangeProposed(msg.sender, newRewardPercentage);
        return proposalId;
    }

    /**
     * @dev Executes the proposal with the given proposalId
     * NOTE In case the proposal is still ongoing or has already been executed, the dao contract will revert
     */

    function execute(uint256 proposalId) public {
        Type proposalType = s_proposalTypes[proposalId];
        bool result = i_dao.execute(proposalId);

        if (proposalType == Type.ADD_FM && result)
            i_poolManager.addFundManager(s_proposalIdToFMAddr[proposalId]);
        else if (proposalType == Type.REMOVE_FM && result)
            i_poolManager.removeFundManager(s_proposalIdToFMAddr[proposalId]);
        else if (proposalType == Type.CHANGE_TIER && result) {
            PoolManager.Tier tier = PoolManager.Tier(
                s_proposalIdToTier[proposalId] - 1
            );
            i_poolManager.setTier(s_proposalIdToFMAddr[proposalId], tier);
        } else if (proposalType == Type.CHANGE_ALLOWANCE && result) {
            PoolManager.Tier tier = PoolManager.Tier(
                s_proposalIdToTier[proposalId] - 1
            );
            i_poolManager.setAllowance(
                tier,
                s_proposalIdToAllowance[proposalId]
            );
        } else if (proposalType == Type.CHANGE_REWARD && result)
            i_poolManager.setRewardPercentage(
                s_proposalIdToRewardPercentage[proposalId]
            );
    }
}
