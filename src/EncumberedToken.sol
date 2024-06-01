// An erc-20 token that implements the encumber interface by blocking transfers.

pragma solidity ^0.8.0;

contract Encumberable {
    // Owner -> Taker -> Amount that can be taken
    mapping(address => mapping(address => uint)) public encumbrances;
    mapping(address => mapping(address => uint)) public allowance;
    mapping(address => uint256) public balanceOf;

    mapping(address => uint) public encumberedBalanceOf;

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

    function availableBalanceOf(address a) public view returns (uint) {
        return (balanceOf[a] - encumberedBalanceOf[a]);
    }

    function approve(address spender, uint256 amount) external {
        allowance[msg.sender][spender] = amount;
    }

    function slash(address owner, uint256 amount) external {
        _spendEncumbrance(owner, msg.sender, amount);
        balanceOf[owner] -= amount;
    }

    function mint(address owner, uint256 amount) external {
        balanceOf[owner] += amount;
    }

    function _encumber(address owner, address taker, uint amount) private {
        require(availableBalanceOf(owner) >= amount, "insufficient balance");
        encumbrances[owner][taker] += amount;
        encumberedBalanceOf[owner] += amount;
    }

    function _release(address owner, address taker, uint amount) private {
        if (encumbrances[owner][taker] < amount) {
            amount = encumbrances[owner][taker];
        }
        encumbrances[owner][taker] -= amount;
        encumberedBalanceOf[owner] -= amount;
    }

    function _spendEncumbrance(address owner, address taker, uint256 amount) internal virtual {
        uint256 currentEncumbrance = encumbrances[owner][taker];
        require(currentEncumbrance >= amount, "insufficient encumbrance");
        uint newEncumbrance = currentEncumbrance - amount;
        encumbrances[owner][taker] = newEncumbrance;
        encumberedBalanceOf[owner] -= amount;
    }
}
