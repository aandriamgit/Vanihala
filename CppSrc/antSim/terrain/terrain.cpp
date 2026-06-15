#include "terrain.hpp"

const int	getIndex(const int &maxValue, const int &x, const int &y)
{
	return (y * maxValue + x);
}

const int	getX(const int &maxValue, const int &index)
{
	return (index % maxValue);
}

const int	getY(const int &maxValue, const int &index)
{
	return (index / maxValue);
}

const int	getMaxIndex(const terrain &t)
{
	return (t.mapSize * t.mapSize);
}

const int	getVertMaxIndex(const terrain &t)
{
	return ((t.mapSize + 1) * (t.mapSize + 1));
}

const int	getIndxCount(const terrain &t)
{
	return (t.mapSize * t.mapSize * 6);
}

const int	getPointsPerRow(const terrain &t)
{
	return (t.mapSize + 1);
}
