#pragma once
#include <cstddef>
#include <vector>

enum class AntState
{
	Searching,
	CarryingFood,
	Returning
};

struct	AntColony
{
	std::size_t antCount;
	std::vector<float> posX;
	std::vector<float> posY;
	std::vector<float> dirX;
	std::vector<float> dirY;
	std::vector<AntState> states;
};

void	initializeColony(AntColony &colony, std::size_t antCount);
void	stepColony(AntColony &colony, float dt = 1.0f);
void	resetColony(AntColony &colony);

const std::vector<float> &getAntsPosX(const AntColony &colony);
const std::vector<float> &getAntsPosY(const AntColony &colony);
const std::vector<AntState> &getAntsStates(const AntColony &colony);
