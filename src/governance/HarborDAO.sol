// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Pool} from "../pool/pool.sol";
import {HarborFactory} from "../factory/harborFactory.sol";

contract HarborDAO {
    error Not_DAO_Member();
    error Proposal_Expired();
    error Already_Voted();
    error Proposal_Ongoing();

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        uint256 indexed poolId
    );
    event VoteCasted(
        uint256 indexed proposalId,
        address indexed voter,
        bool indexed vote
    );
    event ProposalExecuted(uint256 indexed proposalId, Status indexed result);

    enum Status {
        PENDING,
        ACCEPTED,
        REJECTED
    }

    uint256 private constant VOTE_DURATION = 1 weeks;
    uint256 private s_proposalId;
    Proposal[] private s_proposals;
    mapping(address => bool) private s_hasVoted;

    HarborFactory private immutable i_factory;

    struct Proposal {
        Status status;
        address proposer;
        uint256 posVotes;
        uint256 negVotes;
        uint256 numVoters;
        uint256 startTime;
        uint256 deadline;
        uint256 id;
        uint256 poolId;
    }

    constructor(address factoryAddr) {
        s_proposalId = 0;
        i_factory = HarborFactory(factoryAddr);
    }

    /**
     * @dev Creates a new proposal with the given proposer and for the pool with the given poolId and returns the
     *      proposal id
     */

    function createNewProposal(
        address _proposer,
        uint256 _poolId
    ) external returns (uint256) {
        Proposal memory proposal = Proposal({
            status: Status.PENDING,
            proposer: _proposer,
            posVotes: 0,
            negVotes: 0,
            numVoters: 0,
            startTime: block.timestamp,
            deadline: block.timestamp + VOTE_DURATION,
            id: s_proposalId,
            poolId: _poolId
        });
        s_proposals.push(proposal);

        s_proposalId++;
        emit ProposalCreated(proposal.id, proposal.proposer, proposal.poolId);

        return proposal.id;
    }

    /**
     * @dev Allows a dao member to vote on the proposal with the given proposalId
     */

    function vote(uint256 _proposalId, bool _vote) external {
        Proposal storage proposal = s_proposals[_proposalId];
        uint256 poolId = proposal.poolId;
        Pool pool = Pool(i_factory.getPool(poolId));
        uint256 balance = pool.balanceOf(msg.sender);

        if (balance == 0) revert Not_DAO_Member();
        if (block.timestamp > proposal.deadline) revert Proposal_Expired();
        if (s_hasVoted[msg.sender]) revert Already_Voted();

        s_hasVoted[msg.sender] = true;

        if (_vote) proposal.posVotes += balance;
        else proposal.negVotes -= balance;

        proposal.numVoters++;
        emit VoteCasted(proposal.id, msg.sender, _vote);
    }

    /**
     * @dev Executes a proposal if the voting period has ended and returns the result
     */

    function execute(uint256 _proposalId) external returns (bool) {
        Proposal storage proposal = s_proposals[_proposalId];

        if (block.timestamp < proposal.deadline) revert Proposal_Ongoing();
        if (proposal.status != Status.PENDING) revert Proposal_Expired();

        if (proposal.posVotes > proposal.negVotes) {
            proposal.status = Status.ACCEPTED;
            emit ProposalExecuted(proposal.id, proposal.status);

            return true;
        } else {
            proposal.status = Status.REJECTED;
            emit ProposalExecuted(proposal.id, proposal.status);

            return false;
        }
    }

    /**
     * @dev Returns the proposal with the given proposalId
     */

    function getProposal(
        uint256 _proposalId
    ) public view returns (Proposal memory) {
        return s_proposals[_proposalId];
    }

    /**
     * @dev Returns the number of proposals
     */

    function getNumProposals() public view returns (uint256) {
        return s_proposals.length;
    }
}
