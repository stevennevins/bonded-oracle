// An erc-20 token that implements the encumber interface by blocking transfers.

pragma solidity ^0.8.0;

interface IEncumberable {
    /**
     * @notice Encumbers a specified amount of the sender's tokens, preventing them from being transferred until released.
     * @dev This function allows a token holder to encumber their own tokens in favor of a specified taker.
     * @param taker The address which will have the right to release the encumbered tokens.
     * @param amount The amount of tokens to be encumbered.
     */
    function encumber(address taker, uint amount) external;

    /**
     * @notice Encumbers a specified amount of tokens from a specified owner's balance, with the sender's approval.
     * @dev This function allows a spender to encumber tokens from an owner's balance, given that the spender has an allowance.
     * @param owner The address of the token owner whose tokens are to be encumbered.
     * @param taker The address which will have the right to release the encumbered tokens.
     * @param amount The amount of tokens to be encumbered.
     */
    function encumberFrom(address owner, address taker, uint amount) external;

    /**
     * @notice Releases a specified amount of encumbered tokens back to their owner.
     * @dev This function allows a taker to release previously encumbered tokens, restoring them to the owner's available balance.
     * @param owner The address of the token owner whose encumbered tokens are to be released.
     * @param amount The amount of encumbered tokens to be released.
     */
    function release(address owner, uint amount) external;

    /**
     * @notice Returns the available balance of tokens for a specified address, excluding encumbered tokens.
     * @dev This function provides the balance of tokens that are free to be transferred by the owner, not counting those that are encumbered.
     * @param a The address to query the available balance of.
     * @return uint256 The amount of tokens available for transfer.
     */
    function availableBalanceOf(address a) external view returns (uint256);

    /**
     * @notice Returns the amount of tokens encumbered by an owner to a specific spender.
     * @dev This function provides the amount of tokens that an owner has encumbered in favor of a specific spender.
     * @param owner The address of the token owner whose encumbrances are being queried.
     * @param spender The address of the spender who has the right to release the encumbered tokens.
     * @return uint256 The amount of tokens encumbered to the spender.
     */
    function encumbrances(address owner, address spender) external view returns (uint256);

    /**
     * @notice Returns the total encumbered balance of tokens for a specified address.
     * @dev This function provides the total balance of tokens that are encumbered by the owner and cannot be transferred until released.
     * @param owner The address to query the total encumbered balance of.
     * @return uint256 The total amount of encumbered tokens.
     */
    function encumberedBalanceOf(address owner) external view returns (uint256);
}

interface ISlashable is IEncumberable {
    /**
     * @notice Slashes a specified amount from the encumbered balance of an owner, reducing both their total and encumbered balance.
     * @dev This function is typically called in scenarios where an encumbered asset needs to be penalized or confiscated due to a breach of contract or similar.
     *      It is crucial in decentralized finance applications, such as the BondedOracle, where economic incentives and penalties are enforced to ensure compliance and correctness.
     *      The function requires that the caller (msg.sender) must have sufficient encumbrance rights over the owner's assets to perform the slash.
     * @param owner The address of the owner whose encumbered assets are being slashed.
     * @param amount The amount of the assets to slash from the owner's encumbered balance.
     * @dev The caller must have sufficient encumbrance rights over the owner's assets.
     * @dev The owner must have at least `amount` of encumbered assets to be slashed.
     */
    function slash(address owner, uint256 amount) external;
}

contract EncumberedToken is ISlashable {
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;
    mapping(address => uint256) public balanceOf;

    /// The main difference between encumbrances and allowances is that the owner can't transfer
    /// encumbered funds until the spender releases them back to the owner, but the owner still
    /// retains beneficial ownership of the assets.  While an allowance allows a spender to move
    /// the funds, but the spender doesn't have an entitlement to the funds or a duty to release
    /// the allowance back to the owner
    /// @inheritdoc IEncumberable
    mapping(address owner => mapping(address spender => uint256 amount)) public encumbrances;
    /// @inheritdoc IEncumberable
    mapping(address => uint256) public encumberedBalanceOf;

    /// @notice Encumberable will most likely be applied to a token which already has an approval process
    /// In order to support encumberFrom it needs to be applied with a concept of approval and allowances
    /// @param spender the account that can move funds from an owner
    /// @param amount the amount of funds that the spender can move on behalf of the owner
    function approve(address spender, uint256 amount) external {
        allowance[msg.sender][spender] = amount;
    }

    /// @inheritdoc IEncumberable
    function encumber(address taker, uint amount) external {
        _encumber(msg.sender, taker, amount);
    }

    /// @inheritdoc IEncumberable
    function encumberFrom(address owner, address taker, uint amount) external {
        require(allowance[owner][msg.sender] >= amount);
        _encumber(owner, taker, amount);
    }

    /// @inheritdoc IEncumberable
    function release(address owner, uint amount) external {
        _release(owner, msg.sender, amount);
    }

    /// @inheritdoc IEncumberable
    function availableBalanceOf(address a) public view returns (uint256) {
        return (balanceOf[a] - encumberedBalanceOf[a]);
    }

    /// @inheritdoc ISlashable
    function slash(address owner, uint256 amount) external {
        _spendEncumbrance(owner, msg.sender, amount);
        balanceOf[owner] -= amount;
    }

    /**
     * @dev Encumbers a specified amount of the owner's tokens for the taker.
     * This function increases the encumbrance and the encumbered balance for the taker.
     * It requires that the owner has enough available balance to encumber.
     * @param owner Address of the token owner whose tokens are being encumbered.
     * @param taker Address of the entity for whom the tokens are encumbered.
     * @param amount The amount of tokens to be encumbered.
     */
    function _encumber(address owner, address taker, uint amount) internal {
        require(availableBalanceOf(owner) >= amount, "insufficient balance");
        encumbrances[owner][taker] += amount;
        encumberedBalanceOf[owner] += amount;
    }

    /**
     * @dev Releases a specified amount of encumbered tokens of the owner held for the taker.
     * If the requested amount to release is greater than the currently encumbered amount, it releases only the available encumbered amount.
     * This function decreases the encumbrance and the encumbered balance for the taker.
     * @param owner Address of the token owner whose tokens are being released.
     * @param taker Address of the entity for whom the tokens are released.
     * @param amount The amount of tokens to be released.
     */
    function _release(address owner, address taker, uint amount) internal {
        if (encumbrances[owner][taker] < amount) {
            amount = encumbrances[owner][taker];
        }
        encumbrances[owner][taker] -= amount;
        encumberedBalanceOf[owner] -= amount;
    }

    /**
     * @dev Spends a specified amount of encumbered tokens of the owner held for the taker.
     * This function decreases the encumbrance and the encumbered balance for the taker.
     * It requires that the taker has enough encumbered tokens to spend.
     * @param owner Address of the token owner whose encumbered tokens are being spent.
     * @param taker Address of the entity that is spending the encumbered tokens.
     * @param amount The amount of encumbered tokens to be spent.
     */
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
