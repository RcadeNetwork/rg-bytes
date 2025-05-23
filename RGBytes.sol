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

import { ERC721SeaDropUpgradeableExt, ERC721SeaDropStorage } from "../../thirdparty/opensea/seadrop-upgradeable/src/ERC721SeaDropUpgradeableExt.sol";
import { ERC721AUpgradeable } from "../../thirdparty/opensea/seadrop-upgradeable/lib/erc721a-upgradeable/contracts/ERC721AUpgradeable.sol";

contract RGBytes is Initializable, ERC721SeaDropUpgradeableExt, AccessControlUpgradeable, UUPSUpgradeable {
	// ====================================================
	// STORAGE
	// ====================================================

	address[] public allowedOperators;

	bytes32 constant OPERATOR_MANAGEMENT_ROLE = keccak256("OPERATOR_MANAGEMENT_ROLE");
	bytes32 constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

	// ====================================================
	// ERRORS
	// ====================================================

	error OperatorNotAllowed(address operator);

	// ====================================================
	// MODIFIERS
	// ====================================================

	modifier onlyAllowedOperator(address from) virtual {
		if (from != msg.sender) {
			_checkFilterOperator(msg.sender);
		}
		_;
	}
	modifier onlyAllowedOperatorApproval(address operator, bool approved) virtual {
		if (approved) {
			_checkFilterOperator(operator);
		}
		_;
	}

	// ====================================================
	// CONSTRUCTOR / INITIALIZER
	// ====================================================

	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
		_disableInitializers();
	}

	function initialize(
		string memory name_,
		string memory symbol_,
		address[] memory allowedSeaDrop_,
		address[] memory allowedOperators_
	) external initializer initializerERC721A {
		ERC721SeaDropUpgradeableExt.__ERC721SeaDrop_init(name_, symbol_, allowedSeaDrop_);

		__AccessControl_init();
		__UUPSUpgradeable_init();

		_setRoleAdmin(UPGRADER_ROLE, DEFAULT_ADMIN_ROLE);
		_setRoleAdmin(OPERATOR_MANAGEMENT_ROLE, DEFAULT_ADMIN_ROLE);

		_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_grantRole(UPGRADER_ROLE, msg.sender);
		_grantRole(OPERATOR_MANAGEMENT_ROLE, msg.sender);

		allowedOperators = allowedOperators_;
	}

	// ====================================================
	// INTERNAL
	// ====================================================

	function _checkFilterOperator(address operator) internal view {
		// Check only contracts
		if (operator.code.length > 0) {
			uint256 length = allowedOperators.length;
			unchecked {
				for (uint256 i = 0; i < length; ++i) {
					if (allowedOperators[i] == operator) return;
				}
			}
			revert OperatorNotAllowed(operator);
		}
	}

	// ====================================================
	// ROLEGATED
	// ====================================================

	function updateAllowedOperators(address[] calldata _allowedOperators) public onlyRole(OPERATOR_MANAGEMENT_ROLE) {
		allowedOperators = _allowedOperators;
	}

	// ====================================================
	// OVERRIDES
	// ====================================================

	function setApprovalForAll(
		address operator,
		bool approved
	) public override onlyAllowedOperatorApproval(operator, approved) {
		super.setApprovalForAll(operator, approved);
	}

	function approve(address operator, uint256 tokenId) public override onlyAllowedOperatorApproval(operator, true) {
		super.approve(operator, tokenId);
	}

	function transferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
		super.transferFrom(from, to, tokenId);
	}

	function safeTransferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
		super.safeTransferFrom(from, to, tokenId);
	}

	function safeTransferFrom(
		address from,
		address to,
		uint256 tokenId,
		bytes memory data
	) public override onlyAllowedOperator(from) {
		super.safeTransferFrom(from, to, tokenId, data);
	}

	function supportsInterface(
		bytes4 interfaceId
	) public view override(AccessControlUpgradeable, ERC721SeaDropUpgradeableExt) returns (bool) {
		return
			AccessControlUpgradeable.supportsInterface(interfaceId) ||
			ERC721SeaDropUpgradeableExt.supportsInterface(interfaceId) ||
			super.supportsInterface(interfaceId);
	}

	function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

	function _beforeTokenTransfers(
		address _from,
		address _to,
		uint256 _startTokenId,
		uint256 _quantity
	) internal virtual override(ERC721AUpgradeable) {
		super._beforeTokenTransfers(_from, _to, _startTokenId, _quantity);
	}

	// ====================================================
	// PUBLIC
	// ====================================================

	function getAllowedOperators() public view returns (address[] memory) {
		return allowedOperators;
	}

	function batchOwnerOf(uint256[] calldata tokenIds) public view returns (address[] memory) {
		address[] memory owners = new address[](tokenIds.length);

		for (uint256 i = 0; i < tokenIds.length; ) {
			owners[i] = ownerOf(tokenIds[i]);
			unchecked {
				++i;
			}
		}
		return owners;
	}

	function batchBalanceOf(address[] calldata owners) public view returns (uint256[] memory) {
		uint256[] memory balances = new uint256[](owners.length);

		for (uint256 i = 0; i < owners.length; ) {
			balances[i] = balanceOf(owners[i]);
			unchecked {
				++i;
			}
		}
		return balances;
	}
}
