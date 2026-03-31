export interface OsmSearchItem {
  id: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
}

interface NominatimSearchResult {
  place_id: number;
  lat: string;
  lon: string;
  display_name: string;
  name?: string;
}

interface NominatimReverseResult {
  lat: string;
  lon: string;
  display_name: string;
  name?: string;
  address?: {
    amenity?: string;
    building?: string;
    road?: string;
    suburb?: string;
    city?: string;
    town?: string;
    village?: string;
  };
}

function buildDisplayName(name: string | undefined, address: string): string {
  if (name && name.trim()) {
    return name.trim();
  }
  const firstSegment = address.split(',')[0]?.trim();
  return firstSegment || '地图选点';
}

export async function searchOsmLocations(keyword: string): Promise<OsmSearchItem[]> {
  const url = new URL('https://nominatim.openstreetmap.org/search');
  url.searchParams.set('format', 'jsonv2');
  url.searchParams.set('limit', '10');
  url.searchParams.set('q', keyword);
  url.searchParams.set('addressdetails', '1');

  const response = await fetch(url.toString(), {
    headers: {
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    },
  });
  if (!response.ok) {
    throw new Error('OpenStreetMap 地点搜索失败');
  }

  const results = (await response.json()) as NominatimSearchResult[];
  return results.map((item) => ({
    id: String(item.place_id),
    name: buildDisplayName(item.name, item.display_name),
    address: item.display_name,
    latitude: Number(item.lat),
    longitude: Number(item.lon),
  }));
}

export async function reverseOsmLocation(latitude: number, longitude: number): Promise<OsmSearchItem> {
  const url = new URL('https://nominatim.openstreetmap.org/reverse');
  url.searchParams.set('format', 'jsonv2');
  url.searchParams.set('lat', String(latitude));
  url.searchParams.set('lon', String(longitude));
  url.searchParams.set('zoom', '18');
  url.searchParams.set('addressdetails', '1');

  const response = await fetch(url.toString(), {
    headers: {
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    },
  });
  if (!response.ok) {
    throw new Error('OpenStreetMap 逆地理解析失败');
  }

  const result = (await response.json()) as NominatimReverseResult;
  const fallbackName =
    result.address?.amenity ||
    result.address?.building ||
    result.address?.road ||
    result.address?.suburb ||
    result.address?.city ||
    result.address?.town ||
    result.address?.village;

  return {
    id: `${latitude},${longitude}`,
    name: buildDisplayName(result.name || fallbackName, result.display_name),
    address: result.display_name,
    latitude: Number(result.lat),
    longitude: Number(result.lon),
  };
}
