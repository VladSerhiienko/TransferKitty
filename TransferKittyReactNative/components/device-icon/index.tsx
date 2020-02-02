import React from 'react';
import { StyleSheet } from 'react-native';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';

import { Device } from '../../types/device';
import * as colors from '../../styles/colors';

const ICONS = {
    [Device.iPhone]: 'apple-ios',
    [Device.macbook]: 'laptop-mac',
    [Device.android]: 'android'
};

export const DeviceIcon = ({ device }) => (
    <Icon name={ICONS[device]} style={{ ...styles.icon, ...styles[device] }} color="#" />
)

const styles = StyleSheet.create({
    icon: {
        fontSize: 30,
    },
    [Device.iPhone]: {
        color: colors.BLUE ,
    },
    [Device.macbook]: {
        color: colors.BLACK,
    },
})

export default DeviceIcon
