// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {HarborDAO} from "./HarborDAO.sol";
import {PoolManager} from "../pool/poolManager.sol";

contract GovernFM {
    error Already_FM();
    error Not_FM();
    error Forbidden_Tier();

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

    enum Type {
        ADD_FM,
        REMOVE_FM,
        CHANGE_TIER
    }

    mapping(uint256 proposalId => address proposedFMAddr)
        private s_proposalIdToFMAddr;
    mapping(uint256 proposalId => uint256 tier) private s_proposalIdToTier;
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
        s_proposalTypes[proposalId] = Type.CHANGE_TIER;

        emit TierChangeProposed(msg.sender, fundManager, tier);
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
        }
    }
}
