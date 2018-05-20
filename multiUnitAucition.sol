pragma solidity ^0.4.8;

contract Auction {
    // static
    address public owner;
    uint public numberOfSlots;
    // uint public startBlock;
    // uint public endBlock;

    // state
    enum State {none, inited, bidding, summarising, finished, canceled}
    State public state;
    bool public biddingFinished;
    mapping(address => uint256) public fundsByBidder;

    address[] public winners;
    address public winnersCheckBondReceiver;
    uint256 public winnersCheckBond;

    event LogBid(address bidder, uint indexed bid);
    event LogWithdrawal(address withdrawer, address withdrawalAccount, uint amount);
    event LogCanceled();

    function costructor (address _owner, uint _numberOfSlots) 
        public 
    {
        // require(_startBlock < _endBlock);
        // require(_startBlock >= block.number);
        require (_owner != 0);

        owner = _owner;
        numberOfSlots = _numberOfSlots;
        // startBlock = _startBlock;
        // endBlock = _endBlock;
        state = State.inited;
    }
    
    function start() public
        onlyOwner
    {
        require(state == State.inited);
        state = State.bidding;
    }

    function placeBid() public
        payable
        onlyInBiddingPhase
        onlyNotOwner
        returns (bool success)
    {
        // reject payments of 0 ETH
        require(msg.value != 0);

        // calculate the user's total bid based on the current amount they've sent to the contract
        // plus whatever has been sent with this transaction
        uint newBid = fundsByBidder[msg.sender] + msg.value;

        fundsByBidder[msg.sender] = newBid;

        emit LogBid(msg.sender, newBid);
        return true;
    }

    function cancelAuction()
        public
        onlyOwner
        returns (bool success)
    {
        require(state == State.inited || state == State.bidding);
        
        state = State.canceled;
        emit LogCanceled();
        return true;
    }
    
    function summarise(address[] _addresses) public 
        payable
        onlyOwner
        returns (bool success)
    {
        require(state == State.bidding);
        require(_addresses.length <= numberOfSlots);
        
        // reject payments of 0 ETH
        require(msg.value != 0);

        state = State.summarising;
        
        winners = _addresses;
        winnersCheckBond = msg.value;
        winnersCheckBondReceiver = owner;
        return true;
    }
    
    /*
    function fixWinnersMistake(address _newWinner, uint winnerIndex) 
        public
        
    {
        require(state == State.summarising);
        
        // unimplemented
        assert(false);
    }
    */
    
    function finish() 
        public 
        onlyOwner
        returns (bool success)
    {
        require(state == State.summarising);
        
        state = State.finished;
        return true;
    }

    function withdraw()
        public
        returns (bool success)
    {
        require(state == State.finished || state == State.canceled);
        
        address withdrawalAccount;
        uint i;
        
        if (state == State.canceled) {
            // if the auction was canceled, everyone should simply be allowed to withdraw their funds
            withdrawalAccount = msg.sender;
            sendMoney(fundsByBidder[withdrawalAccount], withdrawalAccount);
        } else {
            // the auction finished without being canceled

            if (msg.sender == owner) {
                // the auction's owner should be allowed to withdraw the highestBindingBid
                require(winners.length != 0);
                
                for (i = 0; i < winners.length; i++) {
                    withdrawalAccount = winners[i];
                    sendMoney(fundsByBidder[withdrawalAccount], withdrawalAccount);
                }
            } else {
                for (i = 0; i < winners.length; i++) {
                    if (msg.sender == winners[i]) revert();
                }

                // anyone who participated but did not win the auction should be allowed to withdraw
                // the full amount of their funds
                withdrawalAccount = msg.sender;
                sendMoney(fundsByBidder[withdrawalAccount], withdrawalAccount);
            }
        }

        return true;
    }
    
    function sendMoney(uint256 _withdrawalAmount, address _withdrawalAccount) 
        internal
    {
        require(_withdrawalAmount != 0);

        fundsByBidder[_withdrawalAccount] -= _withdrawalAmount;

        // send the funds
        assert(msg.sender.send(_withdrawalAmount));

        emit LogWithdrawal(msg.sender, _withdrawalAccount, _withdrawalAmount);
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier onlyNotOwner {
        require(msg.sender != owner);
        _;
    }

    modifier onlyInBiddingPhase {
        require(state == State.bidding);
        _;
    }

    modifier onlyNotCanceled {
        require(state != State.canceled);
        _;
    }

    function min(uint a, uint b)
        internal 
        pure
        returns (uint)
    {
        if (a < b) return a;
        return b;
    }
}