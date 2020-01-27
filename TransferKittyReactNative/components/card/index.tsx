import React from 'react';
import { StyleSheet, View } from 'react-native';

export default function Card({ style = {}, children }) {
    return (
        <View style={{ ...styles.container, ...style }}>
            {children}
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
       width: '100%',
       alignSelf: "baseline",
       backgroundColor: '#fcfcfc',
       borderRadius: 5,
       padding: 15,
       paddingVertical: 25,
       marginTop: 15,
       shadowColor: "rgba(0,0,0,0.11)",
       shadowOffset: {
           width: 1.5,
           height: 1.5
       },
       shadowRadius: 6,
       shadowOpacity: 1,
    },
});
