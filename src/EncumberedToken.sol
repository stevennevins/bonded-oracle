// An erc-20 token that implements the encumber interface by blocking transfers.

pragma solidity ^0.8.0;

interface IEncumberable {
    /**
     * @notice Encumbers a specified amount of the sender's tokens, preventing them from being transferred until released.
     * @dev This function allows a token holder to encumber their own tokens in favor of a specified taker.
     * @param taker The address which will have the right to release the encumbered tokens.
     * @param amount The amount of tokens to be encumbered.
     */
    function encumber(address taker, uint256 amount) external;

    /**
     * @notice Encumbers a specified amount of tokens from a specified owner's balance, with the sender's approval.
     * @dev This function allows a spender to encumber tokens from an owner's balance, given that the spender has an allowance.
     * @param owner The address of the token owner whose tokens are to be encumbered.
     * @param taker The address which will have the right to release the encumbered tokens.
     * @param amount The amount of tokens to be encumbered.
     */
    function encumberFrom(address owner, address taker, uint256 amount) external;

    /**
     * @notice Releases a specified amount of encumbered tokens back to their owner.
     * @dev This function allows a taker to release previously encumbered tokens, restoring them to the owner's available balance.
     * @param owner The address of the token owner whose encumbered tokens are to be released.
     * @param amount The amount of encumbered tokens to be released.
     */
    function release(address owner, uint256 amount) external;

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
     * @dev The caller must have sufficient encumbrance rights over the owner's assets.
     * @dev The owner must have at least `amount` of encumbered assets to be slashed.
     * @param owner The address of the owner whose encumbered assets are being slashed.
     * @param amount The amount of the assets to slash from the owner's encumbered balance.
     */
    function slash(address owner, uint256 amount) external;
}

contract EncumberedToken is ISlashable {
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;
    mapping(address owner => uint256 amount) public balanceOf;

    /// The main difference between encumbrances and allowances is that the owner can't transfer
    /// encumbered funds until the spender releases them back to the owner, but the owner still
    /// retains beneficial ownership of the assets.  While an allowance allows a spender to move
    /// the funds, but the spender doesn't have an entitlement to the funds or a duty to release
    /// the allowance back to the owner. ie, The portion of the users balance that are encumbered
    /// to various entities are effectively nontransferable in contract to allowances which remain
    /// transferable by the owner

    /// @inheritdoc IEncumberable
    mapping(address owner => mapping(address spender => uint256 amount)) public encumbrances;
    /// @inheritdoc IEncumberable
    mapping(address owner => uint256 amount) public encumberedBalanceOf;

    /// @notice Encumberable will most likely be applied to a token which already has an approval process
    /// In order to support encumberFrom it needs to be applied with a concept of approval and allowances
    /// @param _spender the account that can move funds from an owner
    /// @param _amount the amount of funds that the spender can move on behalf of the owner
    function approve(address _spender, uint256 _amount) external {
        allowance[msg.sender][_spender] = _amount;
    }

    /// @inheritdoc IEncumberable
    function encumber(address _taker, uint256 _amount) external {
        _encumber(msg.sender, _taker, _amount);
    }

    /// @inheritdoc IEncumberable
    function encumberFrom(address _owner, address _taker, uint256 _amount) external {
        require(allowance[_owner][msg.sender] >= _amount);
        _encumber(_owner, _taker, _amount);
    }

    /// @inheritdoc IEncumberable
    function release(address _owner, uint256 _amount) external {
        _release(_owner, msg.sender, _amount);
    }

    /// @inheritdoc IEncumberable
    function availableBalanceOf(address _owner) public view returns (uint256) {
        return (balanceOf[_owner] - encumberedBalanceOf[_owner]);
    }

    /// @inheritdoc ISlashable
    function slash(address _owner, uint256 _amount) external {
        _spendEncumbrance(_owner, msg.sender, _amount);
        balanceOf[_owner] -= _amount;
    }

    /**
     * @dev Encumbers a specified amount of the owner's tokens for the taker.
     * This function increases the encumbrance and the encumbered balance for the taker.
     * It requires that the owner has enough available balance to encumber.
     * @param _owner Address of the token owner whose tokens are being encumbered.
     * @param _taker Address of the entity for whom the tokens are encumbered.
     * @param _amount The amount of tokens to be encumbered.
     */
    function _encumber(address _owner, address _taker, uint256 _amount) internal {
        require(availableBalanceOf(_owner) >= _amount, "insufficient balance");
        encumbrances[_owner][_taker] += _amount;
        encumberedBalanceOf[_owner] += _amount;
    }

    /**
     * @dev Releases a specified amount of encumbered tokens of the owner held for the taker.
     * If the requested amount to release is greater than the currently encumbered amount, it releases only the available encumbered amount.
     * This function decreases the encumbrance and the encumbered balance for the taker.
     * @param _owner Address of the token owner whose tokens are being released.
     * @param _taker Address of the entity for whom the tokens are released.
     * @param _amount The amount of tokens to be released.
     */
    function _release(address _owner, address _taker, uint256 _amount) internal {
        if (encumbrances[_owner][_taker] < _amount) {
            _amount = encumbrances[_owner][_taker];
        }
        encumbrances[_owner][_taker] -= _amount;
        encumberedBalanceOf[_owner] -= _amount;
    }

    /**
     * @dev Spends a specified amount of encumbered tokens of the owner held for the taker.
     * This function decreases the encumbrance and the encumbered balance for the taker.
     * It requires that the taker has enough encumbered tokens to spend.
     * @param _owner Address of the token owner whose encumbered tokens are being spent.
     * @param _taker Address of the entity that is spending the encumbered tokens.
     * @param _amount The amount of encumbered tokens to be spent.
     */
    function _spendEncumbrance(address _owner, address _taker, uint256 _amount) internal {
        uint256 currentEncumbrance = encumbrances[_owner][_taker];
        require(currentEncumbrance >= _amount, "insufficient encumbrance");
        uint256 newEncumbrance = currentEncumbrance - _amount;
        encumbrances[_owner][_taker] = newEncumbrance;
        encumberedBalanceOf[_owner] -= _amount;
    }

    /// For testing
    function mint(address _owner, uint256 _amount) external {
        balanceOf[_owner] += _amount;
    }
}
