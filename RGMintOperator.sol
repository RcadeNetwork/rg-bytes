// SPDX-License-Identifier: MIT
/*

  _____                 _       _                _____
 |  __ \               | |     (_)              / ____|
 | |__) |_____   _____ | |_   ___ _ __   __ _  | |  __  __ _ _ __ ___   ___  ___
 |  _  // _ \ \ / / _ \| \ \ / / | '_ \ / _` | | | |_ |/ _` | '_ ` _ \ / _ \/ __|
 | | \ \  __/\ V / (_) | |\ V /| | | | | (_| | | |__| | (_| | | | | | |  __/\__ \
 |_|  \_\___| \_/ \___/|_| \_/ |_|_| |_|\__, |  \_____|\__,_|_| |_| |_|\___||___/
                                         __/ |
                                        |___/
 */
pragma solidity 0.8.17;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { IRGBytes } from "./interfaces/IRGBytes.sol";

contract RGMintOperator is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
	// =================== STATE ===================

	enum SaleStatus {
		Idle,
		Funding
	}

	mapping(address => uint256) public userAllowance;

	uint256 public presaleMintPrice;

	address payable public rgTreasury;

	SaleStatus public saleStatus;
	IRGBytes public rgBytesContract;

	bytes32 private constant MINT_MANAGER_ROLE = keccak256("MINT_MANAGER_ROLE");
	bytes32 private constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

	// =================== MODIFIERS ===================

	modifier onlySaleStatus(SaleStatus _status) {
		require(saleStatus == _status, "RGMintOperator: required sale status mismatched");
		_;
	}

	//  =================== EVENTS ===================

	event SaleStatusChanged(SaleStatus oldStatus, SaleStatus newStatus);
	event MintFunded(address indexed user, uint256 amount);
	event MintPriceChanged(uint256 oldPrice, uint256 newPrice);

	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
		_disableInitializers();
	}

	function initialize(
		IRGBytes _rgBytesContract,
		address payable _rgTreasury,
		uint256 _presaleMintPrice
	) public initializer {
		__AccessControl_init();
		__UUPSUpgradeable_init();

		rgTreasury = _rgTreasury;
		rgBytesContract = _rgBytesContract;
		saleStatus = SaleStatus.Idle;
		presaleMintPrice = _presaleMintPrice;

		_setRoleAdmin(MINT_MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
		_setRoleAdmin(UPGRADER_ROLE, DEFAULT_ADMIN_ROLE);
		_setupRole(MINT_MANAGER_ROLE, msg.sender);
		_setupRole(UPGRADER_ROLE, msg.sender);
		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
	}

	//  =================== ROLE-GATED ===================

	function setPresaleMintPrice(
		uint256 _presaleMintPrice
	) external onlyRole(MINT_MANAGER_ROLE) onlySaleStatus(SaleStatus.Idle) {
		emit MintPriceChanged(presaleMintPrice, _presaleMintPrice);

		require(_presaleMintPrice > 0, "RGMintOperator: mint price must be positive");
		presaleMintPrice = _presaleMintPrice;
	}

	function setSaleStatus(SaleStatus _newStatus) external onlyRole(MINT_MANAGER_ROLE) {
		emit SaleStatusChanged(saleStatus, _newStatus);
		saleStatus = _newStatus;
	}

	function setTreasuryAddress(
		address payable _treasury
	) external onlySaleStatus(SaleStatus.Idle) onlyRole(MINT_MANAGER_ROLE) {
		rgTreasury = _treasury;
	}

	function setRGBytesContract(
		IRGBytes _rgBytesContract
	) external onlySaleStatus(SaleStatus.Idle) onlyRole(MINT_MANAGER_ROLE) {
		rgBytesContract = _rgBytesContract;
	}

	///  =================== PUBLIC ===================

	function getTotalPrice(uint256 qty) public view returns (uint256) {
		return qty * presaleMintPrice;
	}

	function getFundedAmount(address _user) public view returns (uint256) {
		return userAllowance[_user] * presaleMintPrice;
	}

	//  =================== EXTERNAL ===================

	function fundMint(uint256 _mintCount) external payable onlySaleStatus(SaleStatus.Funding) nonReentrant {
		require(msg.value == _mintCount * presaleMintPrice, "RGMintOperator: fundMint: incorrect value");
		(bool success, ) = rgTreasury.call{value: msg.value}("");
		if (!success) {
			revert("RGMintOperator: fundMint: treasury send failed");
		}

		userAllowance[msg.sender] += _mintCount;

		emit MintFunded(msg.sender, _mintCount);
	}

	function mintBatch(
		address[] memory _users,
		uint256[] memory _amounts
	) external onlySaleStatus(SaleStatus.Idle) onlyRole(MINT_MANAGER_ROLE) nonReentrant {
		require(_users.length == _amounts.length, "RGMintOperator: mintBatch: length mismatch");

		uint256 length = _users.length;
		for (uint256 i = 0; i < length; ) {
			rgBytesContract.mintSeaDrop(_users[i], _amounts[i]);
			unchecked {
				++i;
			}
		}
	}

	function reset() external onlyRole(MINT_MANAGER_ROLE) {
		saleStatus = SaleStatus.Idle;
	}

	//  =================== INTERNAL ===================

	function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}
}
