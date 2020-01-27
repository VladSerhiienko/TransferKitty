import React from 'react';
import { Animated, StyleSheet, Text, View, Button } from 'react-native';
import LottieView from "lottie-react-native";

import ShareHeader from './components/share-header';

export default function CatenaShare() {
  return (
    <View style={styles.container}>
      <View style={styles.contentWrapper}>
        <ShareHeader />
        <View style={styles.transparentContent}>
          <View style={styles.loader}>
            <LottieView
              style={styles.lottieView}
              source={require('./assets/moving-eye.json')}
              autoPlay
              loop
            />
            <Text style={styles.textContent}>Looking for someone around...</Text>
          </View>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    left: 20,
    right: 20,
    bottom: 100,
    top: 100,
    borderRadius: 25,
  },
  contentWrapper: {
    flex: 1,
  },
  transparentContent: {
    display: 'flex',
    flex: 1,
    opacity: 0.95,
    // alignContent: 'center',
    textAlign: 'center',
    justifyContent: 'center',
    alignSelf: 'center',
    backgroundColor: '#fff',
    width: '100%',
    borderBottomStartRadius: 20,
    borderBottomEndRadius: 20,
  },
  loader: {
    marginTop: 200,
    display: 'flex',
    alignSelf: 'center',
    // flexDirection: 'column-reverse',
    flex: 1,
    width: '100%',
    // marginBottom: 0,
    alignItems: 'center',
  },
  lottieView: {
    // flexGrow: 2,
    // width: '50%',
    // flex: 1,
    height: 100,
  },
  textContent: {
    alignSelf: 'center',
    // marginBottom: 100,
    fontSize: 17,
    fontWeight: '300',
  }
});
