#include "antSim.h"
#include <random>

static std::default_random_engine rng(std::random_device{}());

void	initializeColony(AntColony &colony, std::size_t antCount)
{
	float	angle;

	colony.antCount = antCount;
	colony.posX.assign(antCount, 0.0f);
	colony.posY.assign(antCount, 0.0f);
	colony.dirX.assign(antCount, 0.0f);
	colony.dirY.assign(antCount, 0.0f);
	colony.states.assign(antCount, AntState::Searching);
	std::uniform_real_distribution<float> posDist(-50.0f, 50.0f);
	std::uniform_real_distribution<float> angleDist(0.0f, 2.0f * 3.14159f);
	for (std::size_t i = 0; i < antCount; ++i)
	{
		colony.posX[i] = posDist(rng);
		colony.posY[i] = posDist(rng);
		angle = angleDist(rng);
		colony.dirX[i] = std::cos(angle);
		colony.dirY[i] = std::sin(angle);
		colony.states[i] = AntState::Searching;
	}
}

void	stepColony(AntColony &colony, float dt)
{
	float	speed;

	for (std::size_t i = 0; i < colony.antCount; ++i)
	{
		speed = 10.0f;
		colony.posX[i] += colony.dirX[i] * speed * dt;
		colony.posY[i] += colony.dirY[i] * speed * dt;
	}
}

void	resetColony(AntColony &colony)
{
	initializeColony(colony, colony.antCount);
}

const std::vector<float> &getAntsPosX(const AntColony &colony)
{
	return (colony.posX);
}

const std::vector<float> &getAntsPosY(const AntColony &colony)
{
	return (colony.posY);
}

const std::vector<AntState> &getAntsStates(const AntColony &colony)
{
	return (colony.states);
}
