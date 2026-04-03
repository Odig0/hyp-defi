// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title FootballPoints
 * @dev Contrato ERC-1155 simple para mintear puntos como recompensas por swaps
 * Un token ID = Un equipo (ej: token ID 1 = Brasil)
 */

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FootballPoints is ERC1155, Ownable {
    // Mapeo de direcciones autorizadas para mintear (solo el hook)
    mapping(address => bool) public isMinter;

    // Evento personalizado para auditoría
    event PointsMinted(address indexed to, uint256 indexed teamId, uint256 amount);
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);

    constructor() ERC1155("ipfs://QmPlaceholder/") Ownable(msg.sender) {}

    /**
     * @dev Agregamos una dirección como minter (solo owner)
     * @param _minter La dirección que podrá mintear puntos
     */
    function addMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "Minter invalido");
        isMinter[_minter] = true;
        emit MinterAdded(_minter);
    }

    /**
     * @dev Removemos una dirección como minter
     * @param _minter La dirección a remover
     */
    function removeMinter(address _minter) external onlyOwner {
        isMinter[_minter] = false;
        emit MinterRemoved(_minter);
    }

    /**
     * @dev Mintea puntos para un usuario (solo minters autorizados)
     * @param _to Dirección del usuario que recibe los puntos
     * @param _teamId ID del equipo (token ID en ERC-1155)
     * @param _amount Cantidad de puntos a mintear
     */
    function mint(
        address _to,
        uint256 _teamId,
        uint256 _amount
    ) external {
        require(isMinter[msg.sender], "No tienes permiso de minter");
        require(_to != address(0), "Destinatario invalido");
        require(_amount > 0, "Cantidad debe ser > 0");

        _mint(_to, _teamId, _amount, "");
        emit PointsMinted(_to, _teamId, _amount);
    }

    /**
     * @dev Retorna el URI para metadatos (simplificado)
     */
    function uri(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked("ipfs://QmPlaceholder/", id));
    }
}
