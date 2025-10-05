
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/** 
 * @title KipuBank
 * @author Leandro Masotti
 * @notice KipuBank permite a los usuarios depositar ETH en bóvedas personales y retirar hasta un límite por transacción.
 * @dev Implementa buenas prácticas: errores personalizados, checks-effects-interactions, nonReentrant, eventos, NatSpec.
 */ 
contract KipuBank {

    /*///////////////////////////////////
            State variables
    ///////////////////////////////////*/
    
    ///@notice Immutable global cap for the total funds that can be held by the contract (in wei).
    uint256 public immutable i_bankCap;

    ///@notice The maximum amount a user may withdraw in a single transaction (in wei).
    uint256 public constant WITHDRAW_LIMIT_PER_TX = 5 ether;

    /// @notice Mapping de users => their vault balance (in wei).
    mapping(address => uint256) private _balances;

    /// @notice Total ETH currently held by the bank (in wei).
    uint256 private _totalBankBalance;

    /// @notice Global counter: total number of deposit operations executed on the contract.
    uint256 public totalDepositsCount;

    /// @notice Global counter: total number of withdrawal operations executed on the contract.
    uint256 public totalWithdrawalsCount;

    /// @notice Per-user counters for deposits.
    mapping(address => uint256) private _userDepositsCount;

    /// @notice Per-user counters for withdrawals.
    mapping(address => uint256) private _userWithdrawalsCount;


    /*///////////////////////////////////
                Events
    ///////////////////////////////////*/

    /**
    * @notice Emitted when a user deposits ETH to their vault.
    * @param account The user who deposited.
    * @param amount The amount of ETH deposited (in wei).
    * @param totalBalance The user's new balance after deposit.
    */
    event KipuBank_Deposit(address indexed account, uint256 amount, uint256 totalBalance);

    /**
    * @notice Emitted when a user withdraws ETH from their vault.
    * @param account The user who withdrew.
    * @param amount The amount of ETH withdrawn (in wei).
    * @param totalBalance The user's new balance after withdrawal.
    */
    event KipuBank_Withdrawal(address indexed account, uint256 amount, uint256 totalBalance);

    /*///////////////////////////////////
                Errors
    ///////////////////////////////////*/

    /// @notice Emitted when an operation receives a zero amount where > 0 is required.
    error KB_ZeroAmount();

    /// @notice Emitted when a deposit would exceed the global bank cap.
    error KB_BankCapExceeded(uint256 attempted, uint256 bankCap);

    /// @notice Emitted when a user tries to withdraw more than their balance.
    error KB_InsufficientBalance(address account, uint256 balance, uint256 requested);

    /// @notice Emitted when a single-withdrawal request exceeds the per-transaction limit.
    error KB_WithdrawLimitExceeded(uint256 requested, uint256 perTxLimit);

    /// @notice Emitted when a native transfer fails.
    error KB_TransferFailed(address to, uint256 amount);

    /*///////////////////////////////////
                Modifiers
    ///////////////////////////////////*/
    /**
    * @notice Ensure the deposit amount is > 0.
    * @param amount Amount in wei.
    */
    modifier amountPositive(uint256 amount) {
        if (amount == 0) revert KB_ZeroAmount();
        _;
    }
    /*///////////////////////////////////
                Functions
    ///////////////////////////////////*/
    
    /**
     * @notice Deposit native ETH into the caller's personal vault.
     * @dev Uses checks-effects-interactions. Emits `Deposit`.
     * @dev public so it can be called from other contracts if needed; also provide `receive`.
     */
    function deposit() external payable amountPositive(msg.value) {
        _beforeDeposit(msg.sender, msg.value);

        // effects
        _balances[msg.sender] += msg.value;
        _totalBankBalance += msg.value;

        // bookkeeping
        _incrementDepositCounters(msg.sender);

        // interactions (none external except emitting event)
        emit KipuBank_Deposit(msg.sender, msg.value, _balances[msg.sender]);
    }

    /**
     * @notice Withdraw up to `WITHDRAW_LIMIT_PER_TX` from caller's personal vault.
     * @param amount The amount to withdraw (wei).
     * @dev Enforces per-transaction withdrawal limit, user's balance, and uses nonReentrant.
     * @dev Uses checks-effects-interactions: update state then perform transfer.
     */
    function withdraw(uint256 amount) external amountPositive(amount) {
        // checks
        if (amount > WITHDRAW_LIMIT_PER_TX) revert KB_WithdrawLimitExceeded(amount, WITHDRAW_LIMIT_PER_TX);

        uint256 userBal = _balances[msg.sender];
        if (amount > userBal) revert KB_InsufficientBalance(msg.sender, userBal, amount);

        // effects
        unchecked {
            // safe because amount <= userBal
            _balances[msg.sender] = userBal - amount;
        }
        _totalBankBalance -= amount;
        _incrementWithdrawalCounters(msg.sender);

        // interaction
        _safeTransfer(payable(msg.sender), amount);

        emit KipuBank_Withdrawal(msg.sender, amount, _balances[msg.sender]);
    }

    /**
     * @notice Returns the caller's vault balance.
     * @return balance The balance of the caller in wei.
     */
    function getMyBalance() external view returns (uint256 balance) {
        return _balances[msg.sender];
    }

    /**
     * @notice Returns the vault balance for a specific user.
     * @param account The address queried.
     * @return balance The balance in wei.
     */
    function getBalanceOf(address account) external view returns (uint256 balance) {
        return _balances[account];
    }

    /**
     * @notice Returns the total ETH currently held by the bank.
     * @return totalBalance Total bank balance in wei.
     */
    function getTotalBankBalance() external view returns (uint256 totalBalance) {
        return _totalBankBalance;
    }

    /**
     * @notice Returns the number of deposits made by a given user.
     * @param account The user address.
     * @return count Number of deposits.
     */
    function getUserDepositsCount(address account) external view returns (uint256 count) {
        return _userDepositsCount[account];
    }

    /**
     * @notice Returns the number of withdrawals made by a given user.
     * @param account The user address.
     * @return count Number of withdrawals.
     */
    function getUserWithdrawalsCount(address account) external view returns (uint256 count) {
        return _userWithdrawalsCount[account];
    }

    /**
     * @notice Convenience: deposit by sending plain ETH to contract address.
     * @dev The receive fallback forwards to internal deposit logic.
     */
    receive() external payable {
        // call internal deposit logic to avoid external call to `deposit()`
        if (msg.value == 0) revert KB_ZeroAmount();
        _beforeDeposit(msg.sender, msg.value);

        _balances[msg.sender] += msg.value;
        _totalBankBalance += msg.value;

        _incrementDepositCounters(msg.sender);

        emit KipuBank_Deposit(msg.sender, msg.value, _balances[msg.sender]);
    }

    /**
     * @notice Fallback to reject unexpected calls without data (keeps contract safe).
     */
    fallback() external payable {
        // Allow plain ETH sends to trigger deposit via receive only.
        // If someone calls a non-existent function, revert to avoid accidental ETH loss.
        revert KB_ZeroAmount();
    }

    /*/////////////////////////
            Constructor
    /////////////////////////*/

    /**
    * @notice Deploy the KipuBank with given global cap and per-transaction withdraw limit.
    * @param _bankCap The maximum total ETH the contract may hold (in wei).
    */
    constructor(uint256 _bankCap){
        require(_bankCap > 0, "bankCap must be > 0"); // brief sanity check (constructor only)
        i_bankCap = _bankCap;
    }

    /*/////////////////////////
            Private
    /////////////////////////*/

    /**
     * @notice Internal hook executed before accepting a deposit.
     * @dev Checks bank cap and other preconditions.
     * @param from The depositor address.
     * @param amount Amount in wei to deposit.
     */
    function _beforeDeposit(address from, uint256 amount) private view {
        // Check total cap
        uint256 newTotal = _totalBankBalance + amount;
        if (newTotal > i_bankCap) revert KB_BankCapExceeded(newTotal, i_bankCap);

        (from);
    }

    /**
     * @notice Internal safe native transfer helper using call.
     * @dev Reverts with custom error on failure.
     * @param to Recipient payable address.
     * @param amount Amount in wei.
     */
    function _safeTransfer(address payable to, uint256 amount) private {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert KB_TransferFailed(to, amount);
    }

    /**
    * @notice Private helper to increment deposit counters.
    * @param user The user whose counters are incremented.
    */
    function _incrementDepositCounters(address user) private {
        unchecked {
            totalDepositsCount += 1;
            _userDepositsCount[user] += 1;
        }
    }

    /**
    * @notice Private helper to increment withdrawal counters.
    * @param user The user whose counters are incremented.
    */
    function _incrementWithdrawalCounters(address user) private {
        unchecked {
            totalWithdrawalsCount += 1;
            _userWithdrawalsCount[user] += 1;
        }
    }

    /*/////////////////////////
        View & Pure
    /////////////////////////*/

    /**
    * @notice Returns the immutable bank cap defined at deployment.
    * @return cap The bank cap in wei.
    */
    function getBankCap() external view returns (uint256 cap) {
        return i_bankCap;
    }
}
