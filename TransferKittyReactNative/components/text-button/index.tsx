import React from 'react';
import { StyleSheet, Text, TouchableOpacity } from 'react-native';

export default function TextButton(props) {
    const { children, onPress } = props;
    return (
        <TouchableOpacity onPress={onPress}>
            <Text style={{ ...styles.text, ...props.style,}}>{children}</Text>
        </TouchableOpacity>
    );
}

const styles = StyleSheet.create({
    text: {
        color: 'blue',
    },
});
