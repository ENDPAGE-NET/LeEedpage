import { useEffect, useMemo, useRef, useState } from 'react';
import { Alert, Button, Empty, Input, List, Space, Tag, Typography } from 'antd';
import { EnvironmentOutlined, SearchOutlined } from '@ant-design/icons';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

import { reverseOsmLocation, searchOsmLocations } from '../../lib/osm';

export interface RuleLocationValue {
  location_name?: string | null;
  location_address?: string | null;
  latitude?: number | null;
  longitude?: number | null;
}

interface SearchResultItem {
  id: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
}

interface Props {
  value?: RuleLocationValue;
  onChange?: (value: RuleLocationValue) => void;
}

const DEFAULT_CENTER: [number, number] = [39.90923, 116.397428];

export default function LocationPicker({ value, onChange }: Props) {
  const mapContainerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<L.Map | null>(null);
  const markerRef = useRef<L.Marker | null>(null);
  const onChangeRef = useRef(onChange);
  const [notice, setNotice] = useState('');
  const [searchKeyword, setSearchKeyword] = useState('');
  const [searching, setSearching] = useState(false);
  const [locating, setLocating] = useState(false);
  const [searchResults, setSearchResults] = useState<SearchResultItem[]>([]);

  const currentLocation = useMemo(
    () => ({
      latitude: value?.latitude ?? null,
      longitude: value?.longitude ?? null,
      location_name: value?.location_name ?? null,
      location_address: value?.location_address ?? null,
    }),
    [value],
  );

  useEffect(() => {
    onChangeRef.current = onChange;
  }, [onChange]);

  const applySelection = (item: SearchResultItem) => {
    onChangeRef.current?.({
      latitude: item.latitude,
      longitude: item.longitude,
      location_name: item.name,
      location_address: item.address || item.name,
    });
  };

  const reverseLookup = async (latitude: number, longitude: number) => {
    try {
      const result = await reverseOsmLocation(latitude, longitude);
      applySelection(result);
      setNotice('');
    } catch (error) {
      setNotice(error instanceof Error ? error.message : '逆地理解析失败');
      applySelection({
        id: `${latitude},${longitude}`,
        latitude,
        longitude,
        name: `地图选点 (${latitude.toFixed(6)}, ${longitude.toFixed(6)})`,
        address: '',
      });
    }
  };

  useEffect(() => {
    if (!mapContainerRef.current || mapRef.current) {
      return;
    }

    const center: [number, number] =
      currentLocation.latitude !== null && currentLocation.longitude !== null
        ? [currentLocation.latitude, currentLocation.longitude]
        : DEFAULT_CENTER;

    const map = L.map(mapContainerRef.current, {
      center,
      zoom: 15,
    });

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; OpenStreetMap contributors',
    }).addTo(map);

    const marker = L.marker(center, {
      draggable: true,
      icon: L.divIcon({
        className: 'rule-location-marker',
        html: '<div style="width:18px;height:18px;border-radius:50%;background:#1677ff;border:3px solid #fff;box-shadow:0 4px 12px rgba(0,0,0,0.25);"></div>',
        iconSize: [18, 18],
        iconAnchor: [9, 9],
      }),
    }).addTo(map);

    marker.on('dragend', () => {
      const latLng = marker.getLatLng();
      void reverseLookup(latLng.lat, latLng.lng);
    });

    map.on('click', (event: L.LeafletMouseEvent) => {
      const { lat, lng } = event.latlng;
      marker.setLatLng([lat, lng]);
      void reverseLookup(lat, lng);
    });

    mapRef.current = map;
    markerRef.current = marker;

    return () => {
      map.remove();
      mapRef.current = null;
      markerRef.current = null;
    };
  }, []);

  useEffect(() => {
    if (!mapRef.current || !markerRef.current) {
      return;
    }
    if (currentLocation.latitude === null || currentLocation.longitude === null) {
      markerRef.current.setLatLng(DEFAULT_CENTER);
      mapRef.current.setView(DEFAULT_CENTER, 15);
      return;
    }
    const position: [number, number] = [currentLocation.latitude, currentLocation.longitude];
    markerRef.current.setLatLng(position);
    mapRef.current.setView(position, 16);
  }, [currentLocation.latitude, currentLocation.longitude]);

  const runSearch = async () => {
    const keyword = searchKeyword.trim();
    if (!keyword) {
      setSearchResults([]);
      return;
    }

    setSearching(true);
    try {
      const results = await searchOsmLocations(keyword);
      setSearchResults(results);
      setNotice(results.length ? '' : '未找到匹配地点，请尝试更具体的关键词');
    } catch (error) {
      setSearchResults([]);
      setNotice(error instanceof Error ? error.message : '地点搜索失败，请稍后重试');
    } finally {
      setSearching(false);
    }
  };

  const locateCurrentPosition = async () => {
    if (!navigator.geolocation) {
      setNotice('当前浏览器不支持定位到当前位置');
      return;
    }

    setLocating(true);
    try {
      const position = await new Promise<GeolocationPosition>((resolve, reject) => {
        navigator.geolocation.getCurrentPosition(resolve, reject, {
          enableHighAccuracy: true,
          timeout: 12000,
          maximumAge: 0,
        });
      });

      const latitude = position.coords.latitude;
      const longitude = position.coords.longitude;
      markerRef.current?.setLatLng([latitude, longitude]);
      mapRef.current?.setView([latitude, longitude], 17);
      await reverseLookup(latitude, longitude);
      setNotice('');
    } catch (error) {
      const message =
        error instanceof GeolocationPositionError
          ? error.message
          : error instanceof Error
            ? error.message
            : '当前位置获取失败';
      setNotice(`定位到当前位置失败：${message}`);
    } finally {
      setLocating(false);
    }
  };

  const selectSearchResult = (item: SearchResultItem) => {
    markerRef.current?.setLatLng([item.latitude, item.longitude]);
    mapRef.current?.setView([item.latitude, item.longitude], 17);
    applySelection(item);
  };

  return (
    <Space direction="vertical" size={12} style={{ width: '100%' }}>
      <Space.Compact style={{ width: '100%' }}>
        <Input
          value={searchKeyword}
          onChange={(event) => setSearchKeyword(event.target.value)}
          placeholder="搜索地址、园区、办公楼、门店、地标"
          onPressEnter={() => void runSearch()}
        />
        <Button icon={<SearchOutlined />} loading={searching} onClick={() => void runSearch()}>
          搜索
        </Button>
      </Space.Compact>

      <Button onClick={() => void locateCurrentPosition()} loading={locating} icon={<EnvironmentOutlined />}>
        定位到当前位置
      </Button>

      {notice ? <Alert type="warning" showIcon message={notice} /> : null}

      <div
        ref={mapContainerRef}
        style={{
          width: '100%',
          height: 320,
          borderRadius: 12,
          overflow: 'hidden',
          border: '1px solid #f0f0f0',
        }}
      />

      <Space direction="vertical" size={4} style={{ width: '100%' }}>
        <Typography.Text strong>当前选点</Typography.Text>
        <Space wrap>
          <Tag color="blue" icon={<EnvironmentOutlined />}>
            {currentLocation.location_name || '未选择地点'}
          </Tag>
          {currentLocation.latitude !== null && currentLocation.longitude !== null ? (
            <Tag>
              {currentLocation.latitude.toFixed(6)}, {currentLocation.longitude.toFixed(6)}
            </Tag>
          ) : null}
          <Tag color="gold">OpenStreetMap</Tag>
        </Space>
        <Typography.Text type="secondary">
          {currentLocation.location_address || '可以通过搜索或直接点击地图完成选点'}
        </Typography.Text>
      </Space>

      <div>
        <Typography.Text strong>搜索结果</Typography.Text>
        {searchResults.length ? (
          <List
            style={{ marginTop: 8, border: '1px solid #f0f0f0', borderRadius: 12 }}
            dataSource={searchResults}
            renderItem={(item) => (
              <List.Item
                style={{ cursor: 'pointer', paddingInline: 16 }}
                onClick={() => selectSearchResult(item)}
              >
                <List.Item.Meta
                  title={item.name}
                  description={item.address || `${item.latitude.toFixed(6)}, ${item.longitude.toFixed(6)}`}
                />
              </List.Item>
            )}
          />
        ) : (
          <div style={{ marginTop: 8 }}>
            <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description="暂无搜索结果" />
          </div>
        )}
      </div>
    </Space>
  );
}
