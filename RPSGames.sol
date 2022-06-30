// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./RPSCard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract RPSGames is Ownable, ReentrancyGuard {
    enum Moves {Rock, Paper, Scissors}
    enum Outcomes {Draw, P1Win, P2Win, None}
    enum GameStatus {Idle, Hosted, Finished, P1Adv, P2Adv, NotValid}

    event GameResult(uint GameNum, Outcomes outcome);

    // Card NFT collection
    RPSCard public _card;
    // Games
    GameStatus[6] _games;
    // Fnish time
    uint[6] private _finishTimes;
    // Players' addresses
    address[12] _players;
    // Encrypted moves
    bytes32[12] private _encrMoves;

    function setCardAddress(address card) public {
        // require(address(this) == _card.getLocker(), "This game contract is not set as locker");
        _card = RPSCard(card);
    }

    modifier notLocked() {
        require(!_card.isLocked(msg.sender), "Sender is locked");
        _;
    }

    // Play1, Idle => Hosted
    function play1(uint gameNum, bytes32 encrMove) public notLocked {
        require(_games[gameNum] == GameStatus.Idle, "Game is not idle.");
        require(_card.balanceOf(msg.sender) > 0, "You dont' have any cards.");
        _card.lock(msg.sender);
        _players[gameNum*2] = msg.sender;
        _encrMoves[gameNum*2] = encrMove;
        _games[gameNum] = GameStatus.Hosted;
    }

    // Play1, Hosted => Finished
    function play2(uint gameNum, bytes32 encrMove) public notLocked {
        require(_games[gameNum] == GameStatus.Hosted, "Game is not play1.");
        require(_card.balanceOf(msg.sender) > 0, "You dont' have any cards.");
        _card.lock(msg.sender);
        _players[gameNum*2 + 1] = msg.sender;
        _encrMoves[gameNum*2 + 1] = encrMove;
        _games[gameNum] = GameStatus.Finished;
        _finishTimes[gameNum] = block.number;
    }

    // Reveal, Finished => Idle, P1Adv
    function reveal(uint gameNum, string memory p1Input, uint p1TokenId, string memory p2Input, uint p2TokenId) public {
        // check game status
        require(_games[gameNum] == GameStatus.Finished, "Game is not finished.");
        // check if caller is in the game
        require(_players[gameNum*2] == msg.sender || _players[gameNum*2 + 1] == msg.sender, "You are not in this game.");
        // check if the input match the move stored
        require(_encrMoves[gameNum*2] == keccak256(abi.encodePacked(p1Input, p1TokenId)),"P1 input incorrect.");
        require(_encrMoves[gameNum*2 + 1] == keccak256(abi.encodePacked(p2Input, p2TokenId)),"P2 input incorrect.");
        // check token ownership
        require(_card.ownerOf(p1TokenId) == _players[gameNum*2], "P1 does't own the token.");
        require(_card.ownerOf(p2TokenId) == _players[gameNum*2 + 1], "P2 does't own the token.");
        // check result
        int r = (int)(p1TokenId % 3) - (int)(p2TokenId % 3);
        if (r == 0) {
            emit GameResult(gameNum, Outcomes.Draw);
            _card.unlock(_players[gameNum*2]);
            _card.unlock(_players[gameNum*2 + 1]);
            _card.safeTransferFrom(_players[gameNum*2], address(0xdead), p1TokenId);
            _card.safeTransferFrom(_players[gameNum*2 + 1], address(0xdead), p2TokenId);
        } else if (r == -2 || r == 1) {
            emit GameResult(gameNum, Outcomes.P1Win);
            _card.unlock(_players[gameNum*2]);
            _card.unlock(_players[gameNum*2 + 1]);
            _card.safeTransferFrom(_players[gameNum*2], address(0xdead), p1TokenId);
            _card.safeTransferFrom(_players[gameNum*2 + 1], address(0xdead), p2TokenId);
        } else if (r == -1 || r == 2){
            emit GameResult(gameNum, Outcomes.P2Win);
            _card.unlock(_players[gameNum*2]);
            _card.unlock(_players[gameNum*2 + 1]);
            _card.safeTransferFrom(_players[gameNum*2], address(0xdead), p1TokenId);
            _card.safeTransferFrom(_players[gameNum*2 + 1], address(0xdead), p2TokenId);
        }
        reset(gameNum);
    }


    // Reset the game (Public for only test)
    function reset(uint gameNum) public {
        _players[gameNum*2] = address(0x0);
        _players[gameNum*2 + 1] = address(0x0);
        _games[gameNum] = GameStatus.Idle;
    }

}