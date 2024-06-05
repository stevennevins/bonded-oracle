// An erc-20 token that implements the encumber interface by blocking transfers.

pragma solidity ^0.8.0;

contract Encumberable {
    /// The main difference between encumbrances and allowances is that the owner can't transfer
    /// encumbered funds until the spender releases them back to the owner, but the owner still
    /// retains beneficial ownership of the assets.  While an allowance allows a spender to move
    /// the funds, but the spender doesn't have an entitlement to the funds or a duty to release
    /// the allowance back to the owner
    mapping(address owner => mapping(address spender => uint256 amount)) public encumbrances;
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public encumberedBalanceOf;

    function approve(address spender, uint256 amount) external {
        allowance[msg.sender][spender] = amount;
    }

    function encumber(address taker, uint amount) external {
        _encumber(msg.sender, taker, amount);
    }

    function encumberFrom(address owner, address taker, uint amount) external {
        require(allowance[owner][msg.sender] >= amount);
        _encumber(owner, taker, amount);
    }

    function release(address owner, uint amount) external {
        _release(owner, msg.sender, amount);
    }

    function slash(address owner, uint256 amount) external {
        _spendEncumbrance(owner, msg.sender, amount);
        balanceOf[owner] -= amount;
    }

    function availableBalanceOf(address a) public view returns (uint256) {
        return (balanceOf[a] - encumberedBalanceOf[a]);
    }

    function _encumber(address owner, address taker, uint amount) internal {
        require(availableBalanceOf(owner) >= amount, "insufficient balance");
        encumbrances[owner][taker] += amount;
        encumberedBalanceOf[owner] += amount;
    }

    function _release(address owner, address taker, uint amount) internal {
        if (encumbrances[owner][taker] < amount) {
            amount = encumbrances[owner][taker];
        }
        encumbrances[owner][taker] -= amount;
        encumberedBalanceOf[owner] -= amount;
    }

    function _spendEncumbrance(address owner, address taker, uint256 amount) internal {
        uint256 currentEncumbrance = encumbrances[owner][taker];
        require(currentEncumbrance >= amount, "insufficient encumbrance");
        uint newEncumbrance = currentEncumbrance - amount;
        encumbrances[owner][taker] = newEncumbrance;
        encumberedBalanceOf[owner] -= amount;
    }

    /// For testing
    function mint(address owner, uint256 amount) external {
        balanceOf[owner] += amount;
    }
}
